ruleset my.twilio {
  meta {
    name "my.twilio"
    description << A test module for twilio >>
    author "Forrest Olson"
    configure using 
      apiToken = meta:rulesetConfig{"apiToken"}
      apiSid = meta:rulesetConfig{"apiSid"}
      apiPhone = meta:rulesetConfig{"apiPhone"}
      // apiToken = ""
      // apiSid = ""
      // apiPhone = ""
    provides getMessages, sendMessage
  }

  global {
    base_url = "https://api.twilio.com"
    // Write a function to return a page of messages sent
    getMessages = defaction(pages = none, sendFilter = none, receiveFilter = none) {
      queryString = sendFilter => 
                      (receiveFilter => {"to":receiveFilter, "from":sendFilter} | {"from":sendFilter}) | 
                      (receiveFilter => {"to":receiveFilter} | {})
      // queryString = queryString.put("api_token", apiToken).put("api_sid", apiSid)
      send_directive("say", {"message":http:get(<<#{base_url}/2010-04-01/Accounts/#{apiSid}/Messages>>, qs=queryString)})
          
    }
    // messages = getMessages
    // Write a user-defined action to send an SMS
    sendMessage = defaction(msg, to) {
      queryString = {} //"api_token":apiToken actually a map...
      body = {"body":msg, "to":to, "from":apiPhone}
      // might drop the .json below
      send_directive("say", {"message":http:post(<<#{base_url}/2010-04-01/Accounts/#{apiSid}/Messages.json>>, qs=queryString, json=body)})
      // setting(response)

    }
  }

  rule test_send {
    select when test send

    pre {
      mess = event:attrs{"message"}
    }

    sendMessage(mess, "+14357549364")

  }

  rule test_messages {
    select when test messages

    pre {
      pages = event:attrs{"pages"} => event:attrs{"pages"} | none
      fromFilter = event:attrs{"from"} => event:attrs{"from"} | none
      toFilter = event:attrs{"to"} => event:attrs{"to"} | none
    }

    getMessages(pages, fromFilter, toFilter)

  }
}