/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ChangePasswordControllerTest
 **/
/**
 * An apex page controller that exposes the change password functionality
 */
public with sharing class ChangePasswordController {
  public String oldPassword { get; set; }
  public String newPassword { get; set; }
  public String verifyNewPassword { get; set; }

  public PageReference changePassword() {
    return Site.changePassword(newPassword, verifyNewPassword, oldpassword);
  }

  public ChangePasswordController() {
  }
}
