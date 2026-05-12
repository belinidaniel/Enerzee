/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-12-2026
 * @last modified by  : Daniel Belini
 * @test              : NO_TESTS_MAPPED
 **/
public class Permissions {
  public static Boolean EnableNewOpportunityFlow {
    get {
      return FeatureManagement.checkPermission('EnableNewOpportunityFlow');
    }
  }
}
