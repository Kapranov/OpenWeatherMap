# OpenWeatherMap

The concept of Elixir **processes** is one of the most important to
understand, and it rightly deserves it own manual. Processes are the
fundamental units of concurrency in Elixir, In fact the Erlang VM
supports up to 134 million (!) processes, which would cause all of your
CPUs to happily light up. (I always get a warm, fuzzy feeling when I
know I'm getting my money's worth from my hardware.) The processes
created by the Erlang VM are independent of the operating system;
they're lighter weight and take mere microseconds to created.

We'll build a simple programm that reports the temperature of a given
city/state/country. But first, let's learn about the Actor concurrency
model.

*Actor concurrency model*

Erlang (and therefore Elixir) uses the Actor concurrency model. This
means the following:

* Each **actor** is a process.
* Each process performs a **specific task**.
* To tell a process to do something, you need to **send it a message**.
  The process can reply by **sending back another message**.
* The kinds of messages the process can act on are specific to the
  process itself. In other words, messages are **pattern-matched**.
* Other than that, processes **don't share any information** with other
  processes.

If all ttis seems fuzzy, fret not. If you've done any object-oriented
programming, you'll find that processes resemble objects in many ways.
You could even argue that this is a pure form of object-orientation.

Here's one way to think about actors. Actors are like people. We
communication with each other by talking . For example, suppose my wife
tells me to do the dishes. Of course, I respond by doing the dishes -
I'm a good husband. But if my wife tells me to eat my vegetables, she'll
be ignored - I won't respond to that. In effect, I'm choosing to respond
only to certain kinds of messages. In addition, I don't know what goes
on inside her head, and she doesn't know what goes on inside my head. As
you'll soon see, the actor concurrency model acts the same way: it
responds only to certain kinds of messages.

*Building a weather application*

Conceptually, the application you'll create in this manual is simple
(see figure bottom). The first version accepts a single argument
containing a location, and it reports the temperature in degrees
Celsius. That involves making a HTTP request to an external weather
service and parsing the JSON response to extract the temperature.

Making a single request is trivial. But what happens if you want to find
out the temperatures in 100 cities simultaneously? Assuming that each
request takes 1 second, are you going to wait 100 seconds? Obviously
not! You'll see how to make concurrent requests so you can get the
results as soon as possible.

One of the properties of concurrency is that you never know the order of
the responses. For example, imagine thet you pass in a list of cities in
alphabetical order. The responses you get back are in no way guaranteed
to be in the same order.

How can you ensure that the responses are in the correct order? Read on.
dear reader - you begin your meteorological adventures in Elixir next.

                      ╔═══════════════════╗
                      ║   Weather APIs    ║
                      ╚══════╦═════╦══════╝
                             ║     ║
                             ║     ║
                             ║     ║
       "Singapore"    ╔══════╩═════╩══════╗   `{:ok, 28 °C}`
   <──────────────────╫   Weather Actor   ╫───────────────────>
       1. Request     ╚═══════════════════╝

            **Weather actor handling a single request**

### Nov 2017 Oleg G.Kapranov
