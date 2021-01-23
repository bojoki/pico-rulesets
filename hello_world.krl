ruleset hello_world {
  meta {
    name "Hello World"
    description <<
A first ruleset for the Quickstart
>>
    author "Phil Windley"
    shares hello
  }
   
  global {
    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }
    monkey = function(name) {
      msg = "Hello " + name;
      msg
    }
  }
   
  rule hello_world {
    select when echo hello
    pre {
      name = event:attrs{"name"}.klog("your passed in name: ")
    }
    //action
    send_directive("say", {"something": "Hello " + name})

  }
   
  rule hello_monkey {
    select when echo monkey
    // prelude
    pre {
      name = event:attrs{"name"}.klog("your passed in name: ")
    }
    //action
    every { // allows for multiple actions
      send_directive("say", {"something": "Hello " + (name || "Monkey")})
      // send_directive("say", {"something": "Hello " + (name => name | "monkey2")})
    }
    // i think the klog should show up in the online testing seciton,
    //postlude
  }

}