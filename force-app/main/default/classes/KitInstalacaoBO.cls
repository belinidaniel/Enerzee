/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-04-2025
 * @last modified by  : Daniel Belini
**/
public without sharing class KitInstalacaoBO {
    private static final String CLASS_NAME = 'KitInstalacaoBO';

    public static void sendKitRecordsToSAP(List<Kit_Instalacao__c> newRecordList){
        if(newRecordList == null || newRecordList.isEmpty()){
            return;
        }

        try{
            Set<Id> allKitIds = new Set<Id>();        
            Set<Id> kitWithItemIds = new Set<Id>();
            
            for(Kit_Instalacao__c kit : newRecordList){
                allKitIds.add(kit.Id);
            }

            for(OpportunityLineItem item : [
                SELECT  Kit_Instalacao__c
                FROM    OpportunityLineItem
                WHERE   Kit_Instalacao__c IN :allKitIds
            ]){
                kitWithItemIds.add(item.Kit_Instalacao__c);
            }

            IntegracaoSAPKit.sendKit(kitWithItemIds);
        } catch(Exception e){
            Utils.createLog(CLASS_NAME, 'sendKitRecordsToSAP', e);
            throw e;
        }
    }

    public static void calculateValueKit(List<Kit_Instalacao__c> newRecordList) {
        if(newRecordList == null || newRecordList.isEmpty()){
            return;
        }

        try{
            Map<Id, Kit_Instalacao__c> kitsMap = new Map<Id, Kit_Instalacao__c>();
            Map<Id, Id> oppIdToKitId = new Map<Id, Id>();
        
            for (Kit_Instalacao__c kit : newRecordList) {
                kit.ValorKit__c = 0;
                kitsMap.put(kit.Id, kit);
            }

            System.debug('kitsMap ' + kitsMap);
        
            // Vamos preencher o Map oppIdToKitId
            for (OpportunityLineItem item : [
                SELECT  OpportunityId, Kit_Instalacao__c
                FROM    OpportunityLineItem
                WHERE   Kit_Instalacao__c IN :kitsMap.keySet()
            ]) {
                oppIdToKitId.put(item.OpportunityId, item.Kit_Instalacao__c);
            }
            System.debug('oppIdToKitId ' + oppIdToKitId);

            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
                SELECT  Id, TipoTelhadoEstrutura__c, PotenciaNominalWp__c, TotalProdutos__c
                FROM    Opportunity 
                WHERE   Id IN :oppIdToKitId.keySet()
            ]);
            System.debug('oppMap ' + oppMap);
    
            for (OpportunityLineItem item : [
                SELECT  OpportunityId, Kit_Instalacao__c, Name, TotalPrice
                FROM    OpportunityLineItem
                WHERE   Kit_Instalacao__c IN :kitsMap.keySet()
            ]) {
                Decimal valor = (item.TotalPrice != null) ? item.TotalPrice : 0;
                Opportunity relatedOpp = oppMap.get(item.OpportunityId);
                
                if (relatedOpp != null && ( item.Name.Contains('SOLO') || item.Name.Contains('REGIAO') ) && relatedOpp.TipoTelhadoEstrutura__c == 'Ao Solo' && relatedOpp.PotenciaNominalWp__c != null) {
                    valor *= relatedOpp.PotenciaNominalWp__c;
                }
        
                kitsMap.get(item.Kit_Instalacao__c).ValorKit__c += valor;
            }
        
            // Agora atualizamos as Oportunidades
            for (Opportunity opp : oppMap.values()) {
                Kit_Instalacao__c kitRelacionado = kitsMap.get(oppIdToKitId.get(opp.Id));
                if(kitRelacionado != null){
                    opp.ValorTotalProdutos__c = kitRelacionado.ValorKit__c;
                }
                opp.StatusAprovacaoDesconto__c = null;
                IntegracaoNivelloAprovacaoDesconto.enviarStatusAprovacaoDesconto(new Set<Id>{opp.Id});

            }
        
            update newRecordList;
            
            OpportunityTriggerHandler.disableTrigger();
            update oppMap.values();
            OpportunityTriggerHandler.enableTrigger();
        } catch(Exception e){
            Utils.createLog(CLASS_NAME, 'calculateValueKit', e);
            throw e;
        }
    }
    
    public static void populateKitFields(List<Kit_Instalacao__c> kits) {
        Date today = Date.today();
        Date futureDate = today.addDays(120);
        
        for (Kit_Instalacao__c kit : kits) {
            kit.UnidadeMedidaLocacao__c = 'Unidade';
            kit.TipoMedicao__c = 'Valor';
            kit.AniversarioLinha__c = futureDate;
            kit.VencimentoBase__c = futureDate;
            kit.TipoFaturamento__c = 'Parcelado';
            kit.Recorrencia__c = 'Mensal';
            kit.CodigoImposto__c = 'Venda NF Futura';
        }
    }



    @future(callout=true)
    public static void SendKitUpdate(Set<Id> kitIds) {
        if (kitIds == null || kitIds.isEmpty()) {
            System.debug('SendKitUpdate called with no kit IDs.');
            return;
        }
        System.debug('SendKitUpdate called for kits: ' + kitIds);

        try{
            // Map Opportunity ID to Kit Instalacao ID for efficient lookup
            Map<Id, Id> oppIdToKitIdMap = new Map<Id, Id>();
            for (Kit_Instalacao__c kit : [SELECT Id, Nome_da_Oportunidade__c FROM Kit_Instalacao__c WHERE Id IN :kitIds AND Nome_da_Oportunidade__c != null]) {
                oppIdToKitIdMap.put(kit.Nome_da_Oportunidade__c, kit.Id);
            }

            if (oppIdToKitIdMap.isEmpty()) {
                System.debug('No opportunities found for the given kits.');
                return;
            }

            List<Opportunity> opportunitiesToProcess = [
                SELECT  Id, PotenciaPicoSistema__c, NumeroModulos__c, IdVirtualOffice__c, 
                        BDI__c, Rede3750__c, Pontos__c, Direct__c,
                        CustoAdicionalFixo__c, Instalacao__c, CustoFinanceiroWeg__c,ConsumoAlvo__c,
                        (SELECT ID, product2.Name, Quantity, UnitPrice, product2.Family, product2.ExternalId__c FROM OpportunityLineItems)
                FROM    Opportunity
                WHERE   Id IN :oppIdToKitIdMap.keySet() AND Isclosed = false
            ];
            
            List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

            for (Opportunity opp : opportunitiesToProcess) {
                try{
                    IntegracaoNivelloContrato.EnviarKitRequest requestBody = buildKitRequest(opp);
                    IntegracaoNivelloContrato.EnviarKitResponse response = IntegracaoNivelloContrato.enviarKit(requestBody);

                    if (response != null) {
                        Id relatedKitId = oppIdToKitIdMap.get(opp.Id);
                        opportunitiesToUpdate.add(createOpportunityForUpdate(opp, response, relatedKitId));
                    } else {
                        Utils.createLog(CLASS_NAME, 'SendKitUpdate - enviarKit sem resposta ' + opp.Id, new AuraHandledException('IntegracaoNivelloContrato.enviarKit retornou nulo.'));
                    }
                } catch(Exception e){
                    Utils.createLog(CLASS_NAME, 'SendKitUpdate - opp ' + opp.Id, e);
                }
            }

            if (!opportunitiesToUpdate.isEmpty()) {
                OpportunityTriggerHandler.disableTrigger();
                update opportunitiesToUpdate;
                OpportunityTriggerHandler.enableTrigger();
                System.debug(opportunitiesToUpdate.size() + ' opportunities updated successfully.');
            } else {
                System.debug('No opportunities were updated.');
            }
        } catch(Exception e){
            Utils.createLog(CLASS_NAME, 'SendKitUpdate', e);
            throw e;
        }
    }

    /**
     * @description Builds the request body for the 'enviarKit' callout.
     * @param opp The Opportunity record to build the request from.
     * @return The populated EnviarKitRequest object.
     */
    private static IntegracaoNivelloContrato.EnviarKitRequest buildKitRequest(Opportunity opp) {
        IntegracaoNivelloContrato.EnviarKitRequest request = new IntegracaoNivelloContrato.EnviarKitRequest();
        request.Id = opp.IdVirtualOffice__c;
        request.ConsumoDesejado = opp.ConsumoAlvo__c;
        request.PotenciaPicoSistema = opp.PotenciaPicoSistema__c;
        request.QtdModulos = (opp.NumeroModulos__c != null) ? (Integer)opp.NumeroModulos__c : 0;
        
        request.listProducts = new List<IntegracaoNivelloContrato.Product>();
        for (OpportunityLineItem oli : opp.OpportunityLineItems) {
            IntegracaoNivelloContrato.Product product = new IntegracaoNivelloContrato.Product();
            product.name = oli.Product2.Name;
            product.Qtd = (oli.Quantity != null) ? (Integer)oli.Quantity : 0;
            product.valueUnity = oli.UnitPrice;
            product.productFamily = oli.Product2.Family;
            
            product.externalId = oli.Product2.ExternalId__c;
            request.listProducts.add(product);
        }
        return request;
    }

    /**
     * @description Creates an Opportunity sObject for update based on the API response.
     * @param originalOpp The original Opportunity record.
     * @param response The response from the 'enviarKit' callout.
     * @param kitId The ID of the related Kit_Instalacao__c record.
     * @return The Opportunity sObject ready for DML update.
     */
    private static Opportunity createOpportunityForUpdate(Opportunity originalOpp, IntegracaoNivelloContrato.EnviarKitResponse response, Id kitId) {
        Opportunity oppToUpdate = new Opportunity(Id = originalOpp.Id);

        // Store previous values
        oppToUpdate.ValorAnteriorBDI__c = originalOpp.BDI__c;
        oppToUpdate.ValorAnteriorRede3750__c = originalOpp.Rede3750__c;
        oppToUpdate.ValorAnteriorPontos__c = originalOpp.Pontos__c;
        oppToUpdate.ValorAnteriorDirect__c = originalOpp.Direct__c;

        // Update with new values from the response
        oppToUpdate.BDI__c = response.Bdi;
        oppToUpdate.Rede3750__c = response.Rede;
        oppToUpdate.Pontos__c = response.Pontos;
        oppToUpdate.Direct__c = response.Direct;
        oppToUpdate.CustoAdicionalFixo__c = response.AdditionalFixedCost;
        oppToUpdate.ValorInstalacao__c = response.Installation;
        oppToUpdate.CustoFinanceiroWeg__c = response.FinancialCostWeg;
        
        oppToUpdate.PropostaAlterada__c = true;

        return oppToUpdate;
    }
}