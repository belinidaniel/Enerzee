public with sharing class IntegracaoSAPKit {
    @future(callout=true)
    public static void sendKit(Set<Id> triggerIds){
        List<Kit_Instalacao__c> kitList = [
            SELECT  Id, Name, SucessoIntegracaoSAP__c, StatusBodyIntegracaoSAP__c
            FROM    Kit_Instalacao__c
            WHERE   Id IN :triggerIds
        ];
        
        Map<Id, List<OpportunityLineItem>> kitIdToLineList = new Map<Id, List<OpportunityLineItem>>();
        for(OpportunityLineItem line : [
            SELECT  Id, ProductCode, Kit_Instalacao__c, Quantity, UnitPrice
            FROM    OpportunityLineItem
            WHERE   Kit_Instalacao__c IN :triggerIds
        ]){
            if(!kitIdToLineList.containsKey(line.Kit_Instalacao__c)){
                kitIdToLineList.put(line.Kit_Instalacao__c, new List<OpportunityLineItem>());
            }
            kitIdToLineList.get(line.Kit_Instalacao__c).add(line);
        }

        for(Kit_Instalacao__c kit : kitList){
            KitRequest corpoRequisicao = new KitRequest();
            corpoRequisicao.TreeCode         = kit.Name;
            corpoRequisicao.TreeType         = 'iProductionTree';
            corpoRequisicao.Quantity         = 1;
            corpoRequisicao.PriceList        = null;
            corpoRequisicao.Warehouse        = null;
            corpoRequisicao.PlanAvgProdSize  = null;
            corpoRequisicao.ProductTreeLines = new ProductTreeLine[]{};


            Integer lineIndex = 1;
            for(OpportunityLineItem line : kitIdToLineList.get(kit.Id)){
                ProductTreeLine productTreeLine = new ProductTreeLine();
                productTreeLine.ItemCode           = line.ProductCode;
                productTreeLine.Quantity           = line.Quantity;
                productTreeLine.Warehouse          = null;
                productTreeLine.Price              = line.UnitPrice;
                productTreeLine.CurrencySAP        = 'R$';
                productTreeLine.ParentItem         = corpoRequisicao.TreeCode;
                productTreeLine.PriceList          = null;
                productTreeLine.AdditionalQuantity = null;
                productTreeLine.ChildNum           = lineIndex;

                corpoRequisicao.ProductTreeLines.add(productTreeLine);
                lineIndex++;
            }
            
            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao).replace('CurrencySAP', 'Currency'), 'KitSAP');
                Utils.createLog('IntegracaoSAPKit', 'sendKit ' + kit.Id, response);

                if(response.getBody() != null && response.getBody() != ''){
                    System.debug(response.getBody());
                    
                    Integer[] successSAPResponseCodes = new Integer[]{200, 201, 204};

                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));

                    //Sucesso
                    if(successSAPResponseCodes.contains(statusCode)){

                        System.debug('SUCCESS');
                        kit.SucessoIntegracaoSAP__c = true;
                    }
                    //Erro
                    else{
                        System.debug('ERROR');
                        kit.SucessoIntegracaoSAP__c = false;

                    }
                    kit.StatusBodyIntegracaoSAP__c = statusCode + ' ' + response.getBody() + ' ' + response.getStatus();
                }
            } catch (Exception e){
                Utils.createLog('IntegracaoSAPKit', 'sendKit ' + kit.Id, e);
                
                kit.SucessoIntegracaoSAP__c = false;
                kit.StatusBodyIntegracaoSAP__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }

        KitInstalacaoTriggerHandler.disableTrigger();
        update kitList;
        KitInstalacaoTriggerHandler.enableTrigger();

    }

    private static HttpResponse chamadaIntegracao(String body, String endpointName){
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :endpointName
        ];

        String tokenSAP = [
            SELECT  Id, LastToken__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = 'TokenSAP'
        ].LastToken__c;

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + tokenSAP);
        request.setBody(body);
        
        return Utils.callIntegrationSAP(request);
    }

    public class KitRequest{
        public String            TreeCode;         // ID do Kit - "151.063.1068"
        public String            TreeType;         // Tipo do kit, deve estar como iProductionTree - "iProductionTree" | null
        public Double            Quantity;         // Quantidade - 3.0
        public Integer           PriceList;        // ID da lista de preços - 2 | null
        public String            Warehouse;        // ID do armazenador - "EUA" | null
        public Double            PlanAvgProdSize;  // Quantidade planejada - 4.0
        public ProductTreeLine[] ProductTreeLines;
    }

    public class ProductTreeLine{
        public String  ItemCode;             // ID do item - "151.049.1069"
        public Double  Quantity;             // Quantidade - 2.0
        public String  Warehouse;            // Armazenador - "EUA"
        public Double  Price;                // Preço unitário - 25.0
        public String  CurrencySAP;          // Moeda - "R$"
        public String  ParentItem;           // Referenciar o produto principal - "139.130.426"
        public Integer PriceList;            // ID da lista de preços - 2 | null
        public Double  AdditionalQuantity;   // Quantidade adicional - 0.0
        public Integer ChildNum;             // ID sequencial de cada item - 2
    }
}