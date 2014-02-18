require 'helper'
require 'trigger'

class TestTrigger < TestCase
  describe "event name" do
    it "should parse name and namespace" do
      event = Trigger::EventName.new("greet:spanish")
      assert_equal 'greet', event.name
      assert_equal 'spanish', event.namespace
    end

    it "should parse name without namespace" do
      event = Trigger::EventName.new(:greet)
      assert_equal 'greet', event.name
      assert_nil event.namespace
    end

    it "should ignore empty namespace" do
      event = Trigger::EventName.new('greet:')
      assert_equal 'greet', event.name
      assert_nil event.namespace
    end

    it "should provide full_name (name with namespace)" do
      event = Trigger::EventName.new("greet:spanish")
      assert_equal 'greet:spanish', event.full_name
    end
  end

  describe "event" do
    let(:event) { Trigger::Event.new('greet:spanish', :name => "Chris") }

    it "should have name" do
      assert_equal 'greet', event.name
    end

    it "should have tag" do
      assert_equal 'spanish', event.namespace
    end

    it "should have data" do
      assert_equal({:name => "Chris"}, event.data)
    end

    it "should allow access to data via []" do
      assert_equal 'Chris', event[:name]
    end

    it "should ensure data is a hash" do
      event = Trigger::Event.new(:greet)
      assert_kind_of Hash, event.data
    end
  end

  describe "client" do
    it "should create a new client module" do
      client = Trigger::Client.create
      assert_kind_of Module, client
      assert client.singleton_class.included_modules.include?(Trigger::Client)
    end
  end

  describe "subscription" do
    let(:client) { Trigger::Client.create }

    it "subscribe to an event" do
      subscriber = client.subscribe(:greet) {}
      assert client.subscribers_for(:greet).include?(subscriber)
    end
  end

  describe "subscriber" do
    class GreetSubscriber < Trigger::Subscriber
      def name
        event.data[:name]
      end

      def perform
        return "Hello, #{name}"
      end
    end

    let(:client) { Trigger::Client.create }
    let(:event) { Trigger::Event.new(:greet, :name => "Chris") }

    it "should create new instance and call #perform on .receive" do
      instance = stub
      instance.expects(:perform)
      GreetSubscriber.expects(:new).with(event).returns(instance)
      GreetSubscriber.receive(event)
    end

    it "should execute block for #receive" do
      subscriber = client.subscribe(:greet) do |event|
        return "Hello, #{event.data[:name]}"
      end

      assert_equal 'Hello, Chris',
        subscriber.receive(
          Trigger::Event.new(
            :greet, :name => "Chris"
          )
      )
    end
  end

  describe ".subscribers_for" do
    let(:client)       { Trigger::Client.create }
    let(:subscriber_a) { client.subscribe(:greet) {} }
    let(:subscriber_b) { client.subscribe(:greet) {} }
    let(:subscriber_c) { client.subscribe('greet:spanish') {} }

    it "should return subscribers for event :greet" do
      assert_equal [subscriber_a, subscriber_b, subscriber_c],
        client.subscribers_for(:greet)
    end

    it "should return subscribers for event :greet with tag 'spanish'" do
      assert_equal [subscriber_c],
        client.subscribers_for('greet:spanish')
    end
  end

  describe ".trigger" do
    let(:client) { Trigger::Client.create }
    let(:data)   { Hash.new(:name => "Chris") }

    it "should build event object to deliver" do
      event = client.build_event('greet:sometag', data)

      client.expects(:build_event).with('greet:sometag', data).
        returns(event)

      client.trigger 'greet:sometag', data
    end

    it "should find subscribers with event name and namespace" do
      client.expects(:subscribers_for).with('greet:sometag').
        returns([])

      client.trigger 'greet:sometag', data
    end
  end

  describe ".publish" do
    let(:client) { Trigger::Client.create }
    
    it "should invoke trigger" do
      client.expects(:trigger).with('greet:spanish', :name => "Chris")
      client.publish 'greet:spanish', :name => "Chris"
    end
  end

  describe ".create_inline_subscriber" do
    let(:client) { Trigger::Client.create }

    it "should create an anonymous class which responds to .receive" do
      subscriber = client.create_inline_subscriber do |event|
        return "Hello"
      end

      assert_kind_of Class, subscriber
      assert subscriber.respond_to?(:receive)
      assert_equal 1, subscriber.method(:receive).arity
      assert_equal 'Hello', subscriber.receive(nil)
    end
  end

  describe "override publish" do
    module CustomPublish
      extend Trigger::Client
      def self.buffer
        @buffer ||= []
      end

      def self.buffer=(value)
        @buffer = value
      end

      subscribe :greet do |event|
        CustomPublish.buffer << "Welcome"
      end

      def self.publish(name, *args)
        CustomPublish.buffer << "Dear friend"
        super
      end
    end

    let(:client) { CustomPublish }
    
    it "should invoke publish with super" do
      client.publish(:greet)
      assert_equal [
        'Dear friend',
        'Welcome'
      ], CustomPublish.buffer
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
        GreetTriggers.buffer << "Hello, #{event.data[:name]}"
      end
      
      subscribe 'greet:spanish' do |event|
        GreetTriggers.buffer << "Hola, #{event.data[:name]}"
      end

      class GreetInFrench < Trigger::Subscriber
        def perform
          GreetTriggers.buffer << "Bonjour, #{event.data[:name]}"
        end
      end

      subscribe 'greet:french', GreetInFrench
    end

    before do
      GreetTriggers.buffer = []
    end

    it "should trigger event :greet" do
      GreetTriggers.trigger :greet, :name => "Chris"
      assert_equal [
        'Hello, Chris',
        'Hola, Chris',
        'Bonjour, Chris'
      ], GreetTriggers.buffer
    end

    it "should trigger event 'greet:spanish'" do
      GreetTriggers.trigger 'greet:spanish', :name => "Chris"
      assert_equal ['Hola, Chris'], GreetTriggers.buffer
    end

    it "should trigger event :greet having tag 'french'" do
      GreetTriggers.trigger 'greet:french', :name => "Chris"
      assert_equal ['Bonjour, Chris'], GreetTriggers.buffer
    end
  end
end
