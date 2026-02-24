/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 02-23-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoVOPlano {

    @future(callout=true)
    public static void sendPlano(Set<Id> triggerIds) {
        VOIntegrationService.syncOpportunities(
            triggerIds,
            'LegacyFuture:IntegracaoVOPlano.sendPlano',
            false
        );
    }
}
