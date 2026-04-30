/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-30-2026
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
