module Trigger
  class Event
    attr_reader :name, :tag, :data

    def initialize(name, tag=nil, data={})
      @name = name
      @tag  = tag
      @data = data
      @data = Hash.new unless @data.is_a?(Hash)
    end

    # convenience method to access data properties
    # event[key] is just a shortcut for event.data[key]
    def [](key)
      @data[key]
    end
  end

  class Subscriber
    attr_reader :name, :tag

    def initialize(name, tag, &block)
      @name = name
      @tag  = tag
      @callback = block
    end

    def receive(event)
      @callback.call(event) if @callback
    end
  end

  module Client
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

    # returns all subscribers for given event name and optional tag
    # if tag is provided, the results are filtered to include only
    # those with matching tag
    #
    # subscribers_for(:greet) #=> all :greet subscribers, tag ignored
    # subscribers_for(:greet, 'spanish') #=> only :greent subscribers with tag 'spanish'
    def subscribers_for(name, tag=nil)
      result = subscribers[name.to_sym]
      result = result.select { |e| e.tag == tag } unless tag.nil?
      result
    end

    # creates a new subscriber for the given event name
    # and optional tag
    #
    # the provided block, which is called whenever the subscribed
    # event gets triggered, should accept a single parameter,
    # commonly named +event+, which will be an instance of an
    # Event object:
    #
    # client = Trigger::Client.new
    # client.subscribe :event, 'optional tag' do |event|
    #   # handle event
    # end
    def subscribe(name, tag=nil, &block)
      subscriber = Subscriber.new(name, tag, &block)
      subscribers[name.to_sym] << subscriber
      subscriber
    end

    # build a new Event object for the given event name, tag and data
    def build_event(name, tag, data)
      Event.new(name, tag, data)
    end

    # triggers the given event name which will invoke +receive+ on
    # all applicable subscribers
    #
    # arguments:
    #   name (required) -> event name
    #   tag (optional)  -> tag for event filtering
    #   data (optional) -> data hash for event
    #
    # trigger(:greet, :name => "Chris") #=> name, data
    # trigger(:greet, 'spanish', :name => "Chris") #=> name, tag, data
    def trigger(name, *args)
      data  = args.pop if args.last.is_a?(Hash)
      tag   = args.shift
      event = build_event(name, tag, data)

      subscribers_for(name, tag).each do |subscriber|
        subscriber.receive(event)
      end
    end

    # publish just invokes the trigger immediately
    # subclasses may override this method to perform
    # more advanced processing (such as queueing the event
    # for later triggering)
    def publish(name, *args)
      trigger(name, *args)
    end
  end
end
