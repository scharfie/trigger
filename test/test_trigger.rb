require 'helper'
require 'trigger'

class TestTrigger < TestCase
  describe "subscription" do
    let(:client) { Trigger::Client.create }

    it "subscribe to an event" do
      subscriber = client.subscribe(:greet)
      assert client.subscribers_for(:greet).include?(subscriber)
    end
  end

  describe "a subscriber" do
    let(:client) { Trigger::Client.create }

    it "should execute block for #receive" do
      subscriber = client.subscribe(:greet) do |event|
        return "Hello, #{event.data[:name]}"
      end

      assert_equal 'Hello, Chris',
        subscriber.receive(
          Trigger::Event.new(
            :greet, nil, :name => "Chris"
          )
      )
    end
  end

  describe ".subscribers_for" do
    let(:client)       { Trigger::Client.create }
    let(:subscriber_a) { client.subscribe :greet }
    let(:subscriber_b) { client.subscribe :greet }
    let(:subscriber_c) { client.subscribe :greet, 'spanish' }

    it "should return subscribers for event :greet" do
      assert_equal [subscriber_a, subscriber_b, subscriber_c],
        client.subscribers_for(:greet)
    end

    it "should return subscribers for event :greet with tag 'spanish'" do
      assert_equal [subscriber_c],
        client.subscribers_for(:greet, 'spanish')
    end
  end

  describe ".trigger" do
    let(:client) { Trigger::Client.create }
    let(:data)   { Hash.new(:name => "Chris") }

    it "should build event object to deliver" do
      client.expects(:build_event).with(:greet, 'some tag', data)
      client.trigger :greet, 'some tag', data
    end

    it "should find subscribers with event name and tag" do
      client.expects(:subscribers_for).with(:greet, 'some tag').
        returns([])

      client.trigger :greet, 'some tag', data
    end
  end
   
  describe "integration" do
    module GreetTriggers
      extend Trigger::Client

      def self.buffer
        @buffer ||= []
      end

      def self.buffer=(value)
        @buffer = value
      end

      subscribe :greet do |event|
        buffer << "Hello, #{event.data[:name]}"
      end
      
      subscribe :greet, 'spanish' do |event|
        buffer << "Hola, #{event.data[:name]}"
      end
    end

    before do
      GreetTriggers.buffer = []
    end

    it "should trigger event :greet" do
      GreetTriggers.trigger :greet, :name => "Chris"
      assert_equal ['Hello, Chris', 'Hola, Chris'], GreetTriggers.buffer
    end

    it "should trigger event :greent having tag 'spanish'" do
      GreetTriggers.trigger :greet, 'spanish', :name => "Chris"
      assert_equal ['Hola, Chris'], GreetTriggers.buffer
    end
  end
end
