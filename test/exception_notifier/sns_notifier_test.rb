# frozen_string_literal: true

require 'test_helper'
require 'aws-sdk-sns'

class SnsNotifierTest < ActiveSupport::TestCase
  def setup
    @exception = fake_exception
    @exception.stubs(:class).returns('MyException')
    @exception.stubs(:backtrace).returns(fake_backtrace)
    @exception.stubs(:message).returns("undefined method 'method=' for Empty")
    @options = {
      topic_arn: 'topicARN',
      sns_prefix: '[App Exception]'
    }
    Socket.stubs(:gethostname).returns('example.com')
  end

  # initialize

  test 'should initialize aws notifier with no params' do
    Aws::SNS::Client.expects(:new).with()

    ExceptionNotifier::SnsNotifier.new(@options)
  end

  # call

  test 'should send a sns notification in background' do
    Aws::SNS::Client.any_instance.expects(:publish).with(
      topic_arn: 'topicARN',
      message: "3 MyException occured in background\n" \
             "Exception: undefined method 'method=' for Empty\n" \
             "Hostname: example.com\n" \
             "Backtrace:\n#{fake_backtrace.join("\n")}\n",
      subject: '[App Exception] - 3 MyException occurred'
    )

    sns_notifier = ExceptionNotifier::SnsNotifier.new(@options)
    sns_notifier.call(@exception, accumulated_errors_count: 3)
  end

  test 'should send a sns notification with controller#action information' do
    controller = mock('controller')
    controller.stubs(:action_name).returns('index')
    controller.stubs(:controller_name).returns('examples')

    Aws::SNS::Client.any_instance.expects(:publish).with(
      topic_arn: 'topicARN',
      message: 'A MyException occurred while GET </examples> ' \
             "was processed by examples#index\n" \
             "Exception: undefined method 'method=' for Empty\n" \
             "Hostname: example.com\n" \
             "Backtrace:\n#{fake_backtrace.join("\n")}\n",
      subject: '[App Exception] - A MyException occurred'
    )

    sns_notifier = ExceptionNotifier::SnsNotifier.new(@options)
    sns_notifier.call(@exception,
                      env: {
                        'REQUEST_METHOD' => 'GET',
                        'REQUEST_URI' => '/examples',
                        'action_controller.instance' => controller
                      })
  end

  private

  def fake_exception
    1 / 0
  rescue StandardError => e
    e
  end

  def fake_exception_without_backtrace
    StandardError.new('my custom error')
  end

  def fake_backtrace
    [
      'backtrace line 1',
      'backtrace line 2',
      'backtrace line 3',
      'backtrace line 4',
      'backtrace line 5',
      'backtrace line 6'
    ]
  end
end
