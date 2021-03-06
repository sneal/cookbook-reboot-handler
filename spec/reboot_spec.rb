# encoding: UTF-8

require_relative 'spec_helper'
require File.join File.dirname(__FILE__), '..', 'files', 'default', 'reboot'

describe Reboot do
  Mixlib::ShellOut.class_eval do
    def run_command
      true
    end
  end

  let(:handler) { Reboot.new }
  let(:node) { ChefSpec::Runner.new.converge('reboot-handler::default').node }
  let(:status) do
    Chef::RunStatus.new node, Chef::EventDispatch::Dispatcher.new
  end

  it "doesn't reboot if the run failed" do
    status.exception = Exception.new

    handler.run_report_unsafe(status).should_not be_true
  end

  it "doesn't reboot if the node does not have the enabled_role" do
    handler.run_report_unsafe(status).should_not be_true
  end

  it "doesn't reboot if the node has the enabled_role, but missing the reboot flag" do # rubocop:disable LineLength
    node.stub(:roles).and_return ['booted']

    handler.run_report_unsafe(status).should_not be_true
  end

  context 'with enabled_role and reboot flag' do
    before do
      node.stub(:roles).and_return ['booted']
      node.run_state['reboot'] = true
    end

    it 'reboots' do
      handler.run_report_unsafe(status).should be_true
    end

    it 'issues correct command' do
      obj = double
      obj.stub(:run_command) { true }
      Mixlib::ShellOut.should_receive(:new)
        .with('sync; sync; shutdown -r +1&')
        .and_return(obj)
      handler.run_report_unsafe(status)
    end

    it 'resets run_list if node has a post_boot_runlist attribute' do
      node.set['reboot-handler']['post_boot_runlist'] = ['role[foo]']
      node.stub(:roles).and_return ['booted']
      node.stub :save
      node.run_state['reboot'] = true
      handler.run_report_unsafe(status)

      node.run_list.to_s.should eq 'role[foo]'
    end
  end
end
