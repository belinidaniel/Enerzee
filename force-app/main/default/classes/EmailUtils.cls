public with sharing class EmailUtils {
  public static Messaging.SingleEmailMessage createSingleEmailMessage(
    String subject,
    String htmlBody,
    String[] toAddresses,
    String[] ccAddresses
  ) {
    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setSubject(subject);
    message.setHtmlBody(htmlBody);
    message.setToAddresses(toAddresses);
    message.setCcAddresses(ccAddresses);

    return message;
  }
}
