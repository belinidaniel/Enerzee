/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 02-23-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoVOClientePreCadastro {

    @future(callout=true)
    public static void sendCliente(Set<Id> triggerIds) {
        VOIntegrationService.syncAccounts(
            triggerIds,
            'LegacyFuture:IntegracaoVOClientePreCadastro.sendCliente',
            false
        );
    }

    public static void processAccounts(List<Account> accountList, String logContext) {
        if (accountList == null || accountList.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Account accountRecord : accountList) {
            if (accountRecord != null && accountRecord.Id != null) {
                accountIds.add(accountRecord.Id);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        VOIntegrationService.syncAccounts(
            accountIds,
            String.isBlank(logContext) ? 'Legacy:IntegracaoVOClientePreCadastro.processAccounts' : logContext,
            true
        );
    }
}
