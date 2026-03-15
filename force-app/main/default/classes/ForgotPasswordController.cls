/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ForgotPasswordControllerTest
 **/
/**
 * An apex page controller that exposes the site forgot password functionality
 */
public with sharing class ForgotPasswordController {
  public String username { get; set; }

  public ForgotPasswordController() {
  }

  public PageReference forgotPassword() {
    boolean success = Site.forgotPassword(username);
    PageReference pr = Page.ForgotPasswordConfirm;
    pr.setRedirect(true);

    if (success) {
      return pr;
    }
    return null;
  }
}
