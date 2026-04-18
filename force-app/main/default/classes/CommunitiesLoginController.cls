/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-17-2026
 * @last modified by  : Daniel Belini
 * @test              : CommunitiesLoginControllerTest
 **/
/**
 * An apex page controller that exposes the site login functionality
 */
global with sharing class CommunitiesLoginController {
  global CommunitiesLoginController() {
  }

  // Code we will invoke on page load.
  global PageReference forwardToAuthPage() {
    String startUrl = System.currentPageReference()
      .getParameters()
      .get('startURL');
    String displayType = System.currentPageReference()
      .getParameters()
      .get('display');
    return Network.forwardToAuthPage(startUrl, displayType);
  }
}
