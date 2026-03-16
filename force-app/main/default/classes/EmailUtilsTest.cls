/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
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
