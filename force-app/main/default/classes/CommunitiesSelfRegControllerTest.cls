/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
/**
 * An apex page controller that supports self registration of users in communities that allow self registration
 */
@IsTest
public with sharing class CommunitiesSelfRegControllerTest {
  @IsTest(SeeAllData=true)
  public static void testCommunitiesSelfRegController() {
    CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
    controller.firstName = 'FirstName';
    controller.lastName = 'LastName';
    controller.email = 'test@force.com';
    controller.communityNickname = 'test';

    // registerUser will always return null when the page isn't accessed as a guest user
    System.assert(controller.registerUser() == null);

    controller.password = 'abcd1234';
    controller.confirmPassword = 'abcd123';
    System.assert(controller.registerUser() == null);
  }

  @IsTest(SeeAllData=true)
  static void shouldTrimFieldsAndHandleMismatchedPasswords() {
    Test.setCurrentPage(new PageReference('/apex/CommunitiesSelfReg'));

    CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
    controller.firstName = 'Nome';
    controller.lastName = 'Sobrenome';
    controller.email = 'trim@test.com';
    controller.password = '  senha123  ';
    controller.confirmPassword = '  senha456  ';
    controller.communityNickname = '  apelido-teste  ';

    PageReference result = controller.registerUser();

    System.assertEquals(
      null,
      result,
      'Password mismatch should abort registration.'
    );
    System.assertEquals('senha123', controller.password);
    System.assertEquals('senha456', controller.confirmPassword);
    System.assertEquals('apelido-teste', controller.communityNickname);
    System.assertEquals(
      1,
      ApexPages.getMessages().size(),
      'A validation message should be added when passwords do not match.'
    );
  }

  @IsTest(SeeAllData=true)
  static void shouldAttemptRegistrationWhenPasswordsMatch() {
    Test.setCurrentPage(new PageReference('/apex/CommunitiesSelfReg'));

    CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
    controller.firstName = 'Portal';
    controller.lastName = 'User';
    controller.email = 'portal.user@test.com';
    controller.password = 'abcd1234';
    controller.confirmPassword = 'abcd1234';
    controller.communityNickname = 'portal-user';

    PageReference result = controller.registerUser();

    System.assertEquals(
      null,
      result,
      'Outside guest context registration should not redirect, but must stay stable.'
    );
  }

  @IsTest(SeeAllData=true)
  static void shouldHandleInvalidExternalUserDataGracefully() {
    Test.setCurrentPage(new PageReference('/apex/CommunitiesSelfReg'));

    CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
    controller.firstName = 'Portal';
    controller.lastName = null;
    controller.email = 'invalid.portal.user@test.com';
    controller.password = 'abcd1234';
    controller.confirmPassword = 'abcd1234';
    controller.communityNickname = 'invalid-portal-user';

    PageReference result = controller.registerUser();

    System.assertEquals(
      null,
      result,
      'Invalid user data should not break the controller contract.'
    );
  }

  @IsTest(SeeAllData=true)
  static void shouldHandleNullPasswordSetterAndConfirmPassword() {
    Test.setCurrentPage(new PageReference('/apex/CommunitiesSelfReg'));

    CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
    controller.password = null;
    controller.confirmPassword = null;
    controller.communityNickname = null;

    PageReference result = controller.registerUser();

    Assert.isNull(result, 'Null passwords devem retornar null (passwords match = both null).');
  }
}
