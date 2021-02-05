ruleset test_twilio_module {
  meta {
    
    name "Twilio Module Test"
    description << Houses tests for my custom Twilio module >>
    author "Forrest Olson"
    use module my.twilio2 alias twilio 
      with 
        apiToken = meta:rulesetConfig{"apiToken"}
        apiSid = meta:rulesetConfig{"apiSid"}
        apiPhone = meta:rulesetConfig{"apiPhone"}
    // shares test_get_messages, test_send_message
    shares lastResponse
  }

  global {
    // test_get_messages = function() {
    //   // twilio:messages()
    // }
    // test_send_message = function(msg, to) {
    //   // twilio:sendMessage(msg, to)
    // }
    lastResponse = function() {
      {}.put(ent:lastTimestamp,ent:lastResponse)
    }
  }

  rule retrieve_messages {
    select when testy tryagain
    pre{ 
      fromFilter = event:attrs{"from"} => event:attrs{"from"} | none
      toFilter = event:attrs{"to"} => event:attrs{"to"} | none
      messages = twilio:getMessages(5, fromFilter, toFilter)
    }
    send_directive("say", {"messages": messages})

    // fired {
    //   ent:lastResponse := response
    //   ent:lastTimestamp := time:now()
    //   raise http event "post" attributes event:attrs
    // }
  }
  rule test_all {
    // calling the function and returning the messages
    select when testy twilio

    pre {
      msg = event:attrs{"message"}.klog("your passed in msg: ")
      pages = event:attrs{"pages"} => event:attrs{"pages"} | none
      fromFilter = event:attrs{"from"} => event:attrs{"from"} | none
      toFilter = event:attrs{"to"} => event:attrs{"to"} | none
    }

    every {
      twilio:sendMessage("14357549364", msg)
      twilio:getMessages(pages, fromFilter, toFilter)
    }
  }

  rule test_send_message {
    // defining a rule which actually sends an SMS
    select when testy sendmess

    pre {
      msg = event:attrs{"message"}.klog("your passed in msg: ")
      number = event:attrs{"number"}.klog("your num")
    }
    
    twilio:sendMessage(number, msg) setting (response)

    fired {
      ent:lastResponse := response
      ent:lastTimestamp := time:now()
      raise http event "post" attributes event:attrs
    }
  }

  rule test_messages {
    select when testy messages

    pre {
      pages = event:attrs{"pages"} => event:attrs{"pages"} | none
      fromFilter = event:attrs{"from"} => event:attrs{"from"} | none
      toFilter = event:attrs{"to"} => event:attrs{"to"} | none
    }

    twilio:getMessages(pages, fromFilter, toFilter)
  }
}