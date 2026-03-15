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
global with sharing class CommunitiesLoginControllerTest {
  @IsTest(SeeAllData=true)
  global static void testCommunitiesLoginController() {
    CommunitiesLoginController controller = new CommunitiesLoginController();
    System.assertEquals(null, controller.forwardToAuthPage());
  }
}
