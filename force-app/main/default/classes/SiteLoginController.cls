/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : SiteLoginControllerTest
 **/
/**
 * An apex page controller that exposes the site login functionality
 */
global with sharing class SiteLoginController {
  global String username { get; set; }
  global String password { get; set; }

  global PageReference login() {
    String startUrl = System.currentPageReference()
      .getParameters()
      .get('startURL');
    return Site.login(username, password, startUrl);
  }

  global SiteLoginController() {
  }
}
