/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
/**
 * An apex page controller that exposes the site login functionality
 */
@IsTest
global with sharing class SiteLoginControllerTest {
  @IsTest(SeeAllData=true)
  global static void testSiteLoginController() {
    // Instantiate a new controller with all parameters in the page
    SiteLoginController controller = new SiteLoginController();
    controller.username = 'test@salesforce.com';
    controller.password = '123456';

    System.assertEquals(controller.login(), null);
  }
}
