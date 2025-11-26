public with sharing class IntegracaoSAPContrato {
    @future(callout=true)
    public static void sendContract(Set<Id> triggerIds){
        Map<Id, List<Kit_Instalacao__c>> mapaProdutos = new Map<Id, List<Kit_Instalacao__c>>();

        List<Opportunity> oportunidades = [
            SELECT  Id, Account.SeCPFouCNPJ__c, IdVirtualOffice__c, DataEntrega__c,ValorTotalProposta__c,Numeroproposta__c
            FROM    Opportunity
            WHERE   Id IN :triggerIds
        ];

        List<Kit_Instalacao__c> kits = [
            SELECT  Id, ValorKit__c, Nome_da_Oportunidade__c, Name,
                    AniversarioLinha__c, TipoFaturamento__c, TipoMedicao__c,
                    UnidadeMedidaLocacao__c, VencimentoBase__c, CodigoImposto__c, Nome_da_Oportunidade__r.ValorTotalProposta__c
            FROM    Kit_Instalacao__c
            WHERE   Nome_da_Oportunidade__c IN :triggerIds
        ];

        if(!kits.isEmpty()){

            //Montar mapa de referência para os produtos das Oportunidades
            for(Kit_Instalacao__c kit : kits){
                if(!mapaProdutos.keySet().contains(kits[0].Nome_da_Oportunidade__c)){
                    mapaProdutos.put(kit.Nome_da_Oportunidade__c, new List<Kit_Instalacao__c>{ kit });
                }
                else{
                    mapaProdutos.get(kit.Nome_da_Oportunidade__c).add(kit);
                }
            }

            for(Opportunity opp : oportunidades){

                //Somente fazer callout se houver Kits na Oportunidade
                List<Kit_Instalacao__c> oppKits = mapaProdutos.get(opp.Id);
                ContratoRequest body = new ContratoRequest();

                if(oppKits != null){
                    body.cardCode                = opp.Account.SeCPFouCNPJ__c;
                    body.cardType                = 'C';
                    body.docDate                 = String.valueOf(System.today());
                    body.docDueDate              = String.valueOf(opp.DataEntrega__c);
                    body.numAtCard               = opp.Numeroproposta__c; 
                    body.bpL_IDAssignedToInvoice = 1;


                    //Dados do produto
                    body.documentLines = new List<DocumentLines>();

                    for(Kit_Instalacao__c kit : oppKits){
                        DocumentLines doc = new DocumentLines();
                        doc.itemCode        = kit.Name;
                        doc.quantity        = 1;
                        //doc.price              = kit.ValorKit__c;
                        doc.price           = kit.Nome_da_Oportunidade__r.ValorTotalProposta__c;
                        doc.measureUnitId   = getMeasureUnitIdValue(kit.UnidadeMedidaLocacao__c);
                        doc.measurementById = getMeasurementByIdValue(kit.TipoMedicao__c);
                        doc.billingType     = getBillingTypeValue(kit.TipoFaturamento__c);
                        doc.usage           = getUsageValue(kit.CodigoImposto__c);
                        doc.dueDateBase     = String.valueOf(kit.VencimentoBase__c);
                        doc.birthdayDate    = String.valueOf(kit.AniversarioLinha__c);

                        body.documentLines.add(doc);
                    }
                }

                try{
                    HttpResponse response = chamadaIntegracao(JSON.serialize(body), 'ContratoSAP');
                    Utils.createLog('IntegracaoSAPContrato', 'sendContract ' + opp.Id, response, opp.Id);
    
                    if(response.getBody() != null && response.getBody() != ''){
                        Integer[] successSAPResponseCodes = new Integer[]{200, 201, 204};
    
                        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                        Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));
    
                        //Sucesso
                        if(successSAPResponseCodes.contains(statusCode)){
    
                            System.debug('SUCCESS');
                            opp.SucessoIntegracaoSAP__c = true;
                        }
                        //Erro
                        else{
                            System.debug('ERROR');
                            opp.SucessoIntegracaoSAP__c = false;
    
                        }
                        opp.StatusBodyIntegracaoSAP__c = statusCode + ' ' + response.getBody() + ' ' + response.getStatus();
                    }
                } catch (Exception e){
                    Utils.createLog('IntegracaoSAPContrato', 'sendPedidoVenda ' + opp.Id, e, opp.Id);
                    
                    opp.SucessoIntegracaoSAP__c = false;
                    opp.StatusBodyIntegracaoSAP__c = e.getMessage() + ' ' + e.getStackTraceString();
                }
            }
        }

        OpportunityTriggerHandler.disableTrigger();
        update oportunidades;
        OpportunityTriggerHandler.enableTrigger();
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

    public class ContratoRequest{
        public String              cardCode;
        public String              cardType;
        public String              docDate;
        public String              docDueDate;
        public String              numAtCard;
        public Integer             bpL_IDAssignedToInvoice;
        public List<DocumentLines> documentLines;
    }

    public class DocumentLines {
        public String  itemCode;
        public Integer quantity;
        public Double  price;
        public Integer usage;
        public String  measureUnitId;
        public Integer measurementById;
        public Integer billingType;
        public String  dueDateBase;
        public String  birthdayDate;
    }

    public static String getMeasureUnitIdValue(String fieldValue){
        return  fieldValue.equalsIgnoreCase('Metro')            ? 'm'   :
                fieldValue.equalsIgnoreCase('Metro Quadrados')  ? 'm2'  :
                fieldValue.equalsIgnoreCase('Kilograma')        ? 'kg'  :
                fieldValue.equalsIgnoreCase('Segundos')         ? 's'   :
                fieldValue.equalsIgnoreCase('Horas')            ? 'h'   :
                fieldValue.equalsIgnoreCase('Dia')              ? 'd'   :
                fieldValue.equalsIgnoreCase('Unidade')          ? 'UN'  :
                fieldValue.equalsIgnoreCase('Serviço')          ? 'SV'  : 'SV';
    }


    public static Integer getMeasurementByIdValue(String fieldValue){
        return  fieldValue.equalsIgnoreCase('Valor')        ? 1 :
                fieldValue.equalsIgnoreCase('Percentual')   ? 2 :
                fieldValue.equalsIgnoreCase('Quantidade')   ? 3 : 3;
    }

    public static Integer getBillingTypeValue(String fieldValue){
        return  fieldValue.equalsIgnoreCase('Nenhum')           ? 0 :
                fieldValue.equalsIgnoreCase('Medição')          ? 1 :
                fieldValue.equalsIgnoreCase('Parcelado')        ? 2 :
                fieldValue.equalsIgnoreCase('Recorrente')       ? 3 :
                fieldValue.equalsIgnoreCase('Calculado')        ? 4 :
                fieldValue.equalsIgnoreCase('Parcelado Medido') ? 5 : 5;
    }
    
    public static Integer getUsageValue(String fieldValue){
        return  fieldValue.equalsIgnoreCase('Industrialização')     ? 1 :
                fieldValue.equalsIgnoreCase('Compra Comercial')     ? 3 :
                fieldValue.equalsIgnoreCase('Transferência')        ? 5 :
                fieldValue.equalsIgnoreCase('Conserto ou reparo')   ? 6 :
                fieldValue.equalsIgnoreCase('Compra KIT Weg')       ? 59 :
                fieldValue.equalsIgnoreCase('Compra Ativo Fixo')    ? 8 :
                fieldValue.equalsIgnoreCase('Venda Prod. Própria')  ? 9 :
                fieldValue.equalsIgnoreCase('Venda Adquirida Terc') ? 10 :
                fieldValue.equalsIgnoreCase('Demonstração')         ? 11 :
                fieldValue.equalsIgnoreCase('Compra Consumo')       ? 7 :
                fieldValue.equalsIgnoreCase('Serv. Prestado/Venda') ? 13 :
                fieldValue.equalsIgnoreCase('Agua e Esgoto')        ? 14 :
                fieldValue.equalsIgnoreCase('Aluguel de Imoveis')   ? 15 :
                fieldValue.equalsIgnoreCase('Comissao Consultores') ? 17 :
                fieldValue.equalsIgnoreCase('Compra Comercial ST')  ? 18 :
                fieldValue.equalsIgnoreCase('Compra NF Fut. Remes') ? 19 :
                fieldValue.equalsIgnoreCase('Compra NF Futura')     ? 20 :
                fieldValue.equalsIgnoreCase('Compra de Brindes')    ? 21 :
                fieldValue.equalsIgnoreCase('Copa e Cozinha')       ? 22 :
                fieldValue.equalsIgnoreCase('Cursos e Treinamento') ? 23 :
                fieldValue.equalsIgnoreCase('Desp Aprendiz/Estagi') ? 24 :
                fieldValue.equalsIgnoreCase('Desp. Contratuais')    ? 25 :
                fieldValue.equalsIgnoreCase('Desp. c/ Sistemas')    ? 26 :
                fieldValue.equalsIgnoreCase('Desp. c/ Viagem')      ? 27 :
                fieldValue.equalsIgnoreCase('Energia Eletrica')     ? 28 :
                fieldValue.equalsIgnoreCase('Eventos e Confratern') ? 29 :
                fieldValue.equalsIgnoreCase('Feiras e Exposicoes')  ? 30 :
                fieldValue.equalsIgnoreCase('Ferramentas')          ? 31 :
                fieldValue.equalsIgnoreCase('Fretes s/ Vendas')     ? 32 :
                fieldValue.equalsIgnoreCase('Impostos Estaduais')   ? 33 :
                fieldValue.equalsIgnoreCase('Internet e Telefone')  ? 34 :
                fieldValue.equalsIgnoreCase('Locacao Maq e Equip')  ? 35 :
                fieldValue.equalsIgnoreCase('Lanches e Bebidas')    ? 36 :
                fieldValue.equalsIgnoreCase('Locacao de Veiculo')   ? 37 :
                fieldValue.equalsIgnoreCase('Outras Saidas')        ? 38 :
                fieldValue.equalsIgnoreCase('Publi. e Marketing')   ? 40 :
                fieldValue.equalsIgnoreCase('Rem Merc p conserto')  ? 41 :
                fieldValue.equalsIgnoreCase('Doação ou brinde')     ? 12 :
                fieldValue.equalsIgnoreCase('Serv. Inst Sist Foto') ? 43 :
                fieldValue.equalsIgnoreCase('Outras Entradas')      ? 39 :
                fieldValue.equalsIgnoreCase('Saida Unifor e Acess') ? 44 :
                fieldValue.equalsIgnoreCase('Saida de Mat. Elétri') ? 45 :
                fieldValue.equalsIgnoreCase('Serviços Gerais')      ? 46 :
                fieldValue.equalsIgnoreCase('Serviços Prestados')   ? 47 :
                fieldValue.equalsIgnoreCase('Serviços de Obra')     ? 48 :
                fieldValue.equalsIgnoreCase('Taxa ART')             ? 49 :
                fieldValue.equalsIgnoreCase('Transf. Filiais')      ? 50 :
                fieldValue.equalsIgnoreCase('Transf. Filiais - ST') ? 51 :
                fieldValue.equalsIgnoreCase('Venda NF Futura')      ? 52 :
                fieldValue.equalsIgnoreCase('Venda de Imobilizado') ? 53 :
                fieldValue.equalsIgnoreCase('Visita Tecnica')       ? 54 :
                fieldValue.equalsIgnoreCase('Servico de Topografi') ? 55 :
                fieldValue.equalsIgnoreCase('Venda de Materiais')   ? 56 :
                fieldValue.equalsIgnoreCase('Material Extra Aplic') ? 57 :
                fieldValue.equalsIgnoreCase('Compra Triangulação')  ? 58 :
                fieldValue.equalsIgnoreCase('Venda Triangulacao')   ? 42 :
                fieldValue.equalsIgnoreCase('Farmacia')             ? 60 :
                fieldValue.equalsIgnoreCase('Uniformes e Acessori') ? 61 :
                fieldValue.equalsIgnoreCase('Serv. Manut. Usina')   ? 62 :
                fieldValue.equalsIgnoreCase('Dev. Compra')          ? 63 :
                fieldValue.equalsIgnoreCase('Retorno de Obra')      ? 64 :
                fieldValue.equalsIgnoreCase('Comodato')             ? 65 :
                fieldValue.equalsIgnoreCase('Venda Merc V. Ordem')  ? 66 :
                fieldValue.equalsIgnoreCase('Remessa Merc C. Orde') ? 67 :
                fieldValue.equalsIgnoreCase('Serv Proteção Veicul') ? 68 :
                fieldValue.equalsIgnoreCase('Dev. Comodato')        ? 69 :
                fieldValue.equalsIgnoreCase('Multa Trans Desc Sal') ? 70 :
                fieldValue.equalsIgnoreCase('Dev. Venda')           ? 71 :
                fieldValue.equalsIgnoreCase('Compra Com5405/04/03') ? 72 :
                fieldValue.equalsIgnoreCase('Compra Com6405/04/03') ? 73 :
                fieldValue.equalsIgnoreCase('Manut Veiculos')       ? 74 :
                fieldValue.equalsIgnoreCase('Retorno Rem Conserto') ? 75 :
                fieldValue.equalsIgnoreCase('Manut. Predial')       ? 76 : 76;
    }
}