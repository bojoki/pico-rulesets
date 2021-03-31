// seen message
{
    "ABCD-1234-ABCD-1234-ABCD-125A": 3,
    "ABCD-1234-ABCD-1234-ABCD-129B": 5,
    "ABCD-1234-ABCD-1234-ABCD-123C": 10
}

// rumor messages
{
    "MessageID": "ABCD-1234-ABCD-1234-ABCD-1234:5",
    "SensorID": "BCDA-9876-BCDA-9876-BCDA-9876",
    "Temperature": "78",
    "Timestamp": <ISO DATETIME>,
}

// gossip algorithm
when gossip_heartbeat {
    subscriber = getPeer(state)                    
    m = prepareMessage(state, subscriber)       
    send (subscriber, m)            
    update(state)     
  }

// uses the current state to determine one peer to send a message to. 
// This is not as simple as picking a node at random. 
// You must choose a peer that needs something from you. If the peer knows your current temperature and it's last seen message indicates that it has seen everything you already know, then you don't need to send it anything. You should try to be fair, not simply pick the first node who needs something from you. You're going to have to keep state about who knows what (to the best of your knowledge) and use that state to determine which peer to send a message to.
getPeer()

// return a message to propagate to a specific neighbor; randomly choose a needed message type, and if it's a rumor, which message.
prepareMessage()

// update state of who has been sent what.
update()

// send a message to the peer
send()

// Each pico should also include two rules for responding the messages: one for responding to rumor events and one for responding to seen events. 
// Use gossip rumor and gossip seen respectively for the domain and type to select on those events.

