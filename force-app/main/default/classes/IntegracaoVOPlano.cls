/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 02-13-2026
 * @last modified by  : GPT-5 Codex
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
