module Trigger
  class Event
    attr_reader :data

    def self.wrap(event_or_name, data={})
      return event_or_name if event_or_name.is_a?(Trigger::Event)
      return new(event_or_name, data)
    end

    def initialize(name, data={})
      @event_name = EventName.new(name)
      @data = data
      @data = Hash.new unless @data.is_a?(Hash)
    end

    def name
      @event_name.name
    end

    def namespace
      @event_name.namespace
    end

    def full_name
      @event_name.full_name
    end

    # convenience method to access data properties
    # event[key] is just a shortcut for event.data[key]
    def [](key)
      @data[key]
    end
  end

  class EventName
    attr_accessor :name, :namespace

    def initialize(name)
      @name, @namespace = self.class.parse(name)
    end

    def full_name
      return @name if @namespace.nil?
      [@name, @namespace].join(':')
    end

    def self.parse(name)
      name, namespace = name.to_s.split(':')
      namespace = namespace || namespace
      namespace = nil if namespace == ''
      return name, namespace
    end
  end

  class Subscriber
    attr_accessor :event

    def initialize(event_or_name, data={})
      @event = Trigger::Event.wrap(event_or_name, data)
    end

    def perform
      raise "Subscriber#perform not implemented"
    end

    def self.receives(*names)
      Array.wrap(names).flatten.each do |name|
        define_method(name) do
          event[name]
        end
      end
    end

    def self.receive(event_or_name, data={})
      event = Trigger::Event.wrap(event_or_name, data)
      new(event).perform
    end
  end

  module Client
    @enabled = true

    # convenience method for creating a new client module
    # effectively the same as:
    # module SomeModule
    #   extend Trigger::Client
    # end
    def self.create
      client = self
      Module.new { extend client }
    end


    def subscribers
      @subscribers ||= Hash.new { |h,k| h[k] = [] }
    end

    # returns all subscribers for given event name
    # if the name is namespaced e.g. 
    # subscribers_for(:greet) #=> all :greet subscribers, tag ignored
    # subscribers_for(:greet, 'spanish') #=> only :greet subscribers with tag 'spanish'
    def subscribers_for(name)
      event_name = EventName.new(name)
      name       = event_name.name.to_sym
      namespace  = event_name.namespace

      result = subscribers[name]
      result = result.map do |e|
        e[:class] if namespace.nil? || e[:namespace] == namespace
      end.compact
    end

    def create_inline_subscriber(&block)
      Class.new do
        define_singleton_method :receive, block
      end
    end

    # creates a new subscriber for the given event name,
    # which can be namespaced if desired using name:namespace
    #
    # the provided block, which is called whenever the subscribed
    # event gets triggered, should accept a single parameter,
    # commonly named +event+, which will be an instance of an
    # Event object:
    #
    # client = Trigger::Client.new
    # client.subscribe "greet" do |event|
    #   # handle event
    # end
    def subscribe(name, *args, &block)
      if block_given?
        # we received a block, so create a new subscriber inline
        # and optional tag form args
        subscriber = create_inline_subscriber(&block)
      else
        # no block, so the last argument is assumed to be a
        # callback class
        klass = args.pop
        subscriber = klass

        raise "Subscriber class must repond to .receive" unless subscriber.respond_to?(:receive)
      end

      name, namespace = EventName.parse(name)

      subscribers[name.to_sym] << { :class => subscriber, :namespace => namespace }
      subscriber
    end

    # build a new Event object for the given event name and data
    def build_event(name, data)
      Event.new(name, data)
    end

    # triggers the given event name which will invoke +receive+ on
    # all applicable subscribers
    #
    # arguments:
    #   name (required) -> event name
    #   data (optional) -> data hash for event
    #
    # trigger(:greet, :name => "Chris") #=> name, data
    # trigger(:greet, 'spanish', :name => "Chris") #=> name, data
    def trigger(name, data={})
      event = build_event(name, data)

      subscribers_for(event.full_name).each do |subscriber|
        subscriber.receive(event)
      end
    end

    # publish just invokes the trigger immediately
    # subclasses may override this method to perform
    # more advanced processing (such as queueing the event
    # for later triggering)
    def publish(name, data={})
      trigger(name, data)
    end

    def enabled?
      !!@enabled
    end

    def disabled?
      !@enabled?
    end

    def disable!
      @enabled = false
    end

    def enable!
      previous = @enabled

      @enabled = true

      if block_given?
        begin
          yield
        ensure
          @enabled = previous
        end
      end

      self
    end
  end
end
