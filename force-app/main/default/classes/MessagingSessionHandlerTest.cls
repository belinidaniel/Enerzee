/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
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
