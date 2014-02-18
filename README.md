# trigger

Trigger is a simple library for creating event subscribers.

## Creating a Trigger client

The first step is to create a Trigger client, which will contain all the
subscription configuration:

```ruby
class MyClient
  extend Trigger::Client
end
```

## Adding a subscriber

There are two ways to add a subscriber: inline or explicit. 

### Adding an inline subscriber

```ruby
  subscribe :greet do |event|
    puts "Hello, #{event[:name]}"
  end
```

### Adding an explicit subscriber

To add an explicit subscriber, you simply create a subscriber class
and pass it to the subscribe call instead of the block.

```ruby
  class MyClient
    extend Trigger::Client

    class Greeter < Trigger::Subscriber
      def perform
        puts "Hello, #{event[:name]}"
      end
    end

    subscribe :greet, Greeter
  end
```

We simply subclass ```Trigger::Subscriber``` and provide a perform method.  The event
will be available for you to read data.

*Note*: there's nothing inherently special about the ```Trigger::Subscriber``` class;
in fact your subscriber can be a PORO (plain old ruby object) as long as it
responds to a ```receive``` class-method:

```ruby
  class Greeter
    def self.receive(event)
      puts "Hello, #{event[:name]}
    end
  end
```

## Publishing an event

To publish an event, simply call ```.publish```:

```ruby
  MyClient.publish(:greet, :name => "Chris")
```

Alternatively, you may call ```.trigger``` with the same arguments.  In
fact, the default implementation of publish is to invoke trigger.  The
primary reason for this design decision is to allow you to customize _how_
publishing an event should happen.

```ruby
  class MyClient
    extend Trigger::Client

    def self.publish(name, data={})
      puts "Preparing to execute #{name}"
      trigger(name, data)
    end
  end
```

## Namespaced events

If you want to organize your events in some fashion, you can scope events
using a namespace.  The format is ```name:namespace```.  If
you publish an event with a namespace, only the subscribers for that
event and namespace are called.  However, if you publish an event
without a namespace, all subscribers for that event are called (the namespace
of the subscriber is effectively ignored).

```ruby
  subscribe 'greet:spanish' do |event|
    ...
  end

  # invoke only 'greet' events in 'spanish' namespace
  publish('greet:spanish', { ... })

  # invoke all 'greet' events
  publish('greet', { ... })
```

## Reference

### Event object

When a subscriber receives a message, an event object is passed as
parameter.  The object has the following properties:

```ruby
  e = Event.new("greet", :name => "Chris")
  e.name       #=> 'greet'
  e.namespace  #=> nil
  e.full_name  #=> 'greet'
  e.data       #=> { :name => "Chris" }
  e[:name]     #=> "Chris"

  e2 = Event.new("greet:spanish")
  e2.name      #=> 'greet'
  e2.namespace #=> 'spanish'
  e2.full_name #=> 'greet:spanish'

## Contributing to trigger
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2014 Chris Scharf. See LICENSE.txt for
further details.

