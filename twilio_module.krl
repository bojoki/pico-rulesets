ruleset twilio.module {
  meta {
    name "Twilio Module"
    description << A test module for twilio >>
    author "Forrest Olson"
    configure using 
      apiToken = ""
      apiSid = ""
      apiPhone = ""
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
      http:get(<<#{base_url}/2010-04-01/Accounts/#{apiSid}/Messages.json>>, qs=queryString)    
    }
    messages = getMessages
    // Write a user-defined action to send an SMS
    sendMessage = defaction(msg, to) {
      queryString = {} //"api_token":apiToken actually a map...
      body = {"body":msg, "to":to, "from":apiPhone}
      // might drop the .json below
      response = http:post(<<#{base_url}/2010-04-01/Accounts/#{apiSid}/Messages.json>>, qs=queryString, json=body) 
      // setting(response)
    }
  }

  rule test_send {
    select when test send

    pre {

    }

  }

  rule test_messages {
    select when test messages

    pre {

    }

  }
}