@IsTest
public with sharing class MessagingSessionHandlerTest {
  @IsTest
  public static void shouldCallConversionUpdate() {
    Test.startTest();

    try {
      MessagingSessionHandler.callConversionUpdate(
        new List<String>{ 'id_messaging' }
      );
    } catch (Exception ex) {
    }

    Test.stopTest();
  }
}
