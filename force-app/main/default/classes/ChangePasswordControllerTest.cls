/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
/**
 * An apex page controller that exposes the change password functionality
 */
@IsTest
public with sharing class ChangePasswordControllerTest {
  @IsTest(SeeAllData=true)
  public static void testChangePasswordController() {
    // Instantiate a new controller with all parameters in the page
    ChangePasswordController controller = new ChangePasswordController();
    controller.oldPassword = '123456';
    controller.newPassword = 'qwerty1';
    controller.verifyNewPassword = 'qwerty1';

    System.assertEquals(controller.changePassword(), null);
  }
}
