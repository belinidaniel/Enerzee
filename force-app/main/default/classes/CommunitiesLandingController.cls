/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : CommunitiesLandingControllerTest
 **/
/**
 * An apex page controller that takes the user to the right start page based on credentials or lack thereof
 */
public with sharing class CommunitiesLandingController {
  // Code we will invoke on page load.
  public PageReference forwardToStartPage() {
    return Network.communitiesLanding();
  }

  public CommunitiesLandingController() {
  }
}
