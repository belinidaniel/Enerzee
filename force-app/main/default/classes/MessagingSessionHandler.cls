global with sharing class MessagingSessionHandler {
  @InvocableMethod(label='Call Conversation Update')
  global static void callConversionUpdate(List<String> messagingId) {
    Flow.interview.Messaging_Session_Conversation_Update conversationUpdate = new Flow.interview.Messaging_Session_Conversation_Update(
      new Map<String, String>{ 'messagingId' => messagingId[0] }
    );

    conversationUpdate.start();
  }
}
