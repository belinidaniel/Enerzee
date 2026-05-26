/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-26-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class MessagingComposerControllerTest {
  @IsTest
  static void testSearchRecipients() {
    Account acc = new Account(Name = 'Conta Teste', Phone = '11999990000');
    insert acc;

    Contact con = new Contact(
      LastName = 'Cliente Teste',
      AccountId = acc.Id,
      Phone = '11988880000'
    );
    insert con;

    Test.startTest();
    List<MessagingComposerController.RecipientDTO> results = MessagingComposerController.searchRecipients(
      'Teste'
    );
    Test.stopTest();

    System.assert(
      !results.isEmpty(),
      'Deve retornar ao menos um resultado da busca.'
    );
  }

  @IsTest
  static void testGetMessageDefinitions() {
    Test.startTest();
    List<MessagingComposerController.MessageTemplateDTO> defs = MessagingComposerController.getMessageDefinitions(
      null
    );
    Test.stopTest();

    System.assert(
      !defs.isEmpty(),
      'Stub de templates precisa retornar valores em teste.'
    );
    System.assertEquals('Template_De_Teste', defs[0].fullName);
  }
}
