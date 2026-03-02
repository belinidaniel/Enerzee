@isTest
public class EmailUtilsTest {
  @isTest
  static void createSingleEmailMessageTest() {
    EmailUtils.createSingleEmailMessage(
      'Subject',
      'Body',
      new List<String>{ 'teste@teste.com' },
      new List<String>{ 'teste@teste.com' }
    );
  }
}
