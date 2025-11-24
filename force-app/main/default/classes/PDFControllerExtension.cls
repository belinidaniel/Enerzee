/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-24-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class PDFControllerExtension {

    //Objetivo: providencia métodos para salvar páginas PDF como arquivos vinculados ao registro pai
    public List<String> pdfUrls { get; private set; }
    public String selectedCoverId {get; set;}
    private ApexPages.standardController controller;
    private Opportunity opportunity;
    private String salvar { get; set; }
    private Boolean isManual { get; set; }
    private Boolean isChanged { get; set; }
    public Boolean lastSaveSuccess { get; set; }
    public String  lastSaveMessage { get; set; }
    public String  description { get; set; }
    // Controle estático para evitar múltiplas execuções concorrentes para a mesma oportunidade
    private static Set<Id> processingOpps = new Set<Id>();
    public List<String> viabilityEnerzeeCostEntries { get; private set; }
    public List<String> viabilityClientCostEntries { get; private set; }
    public String mainViabilityStudyText { get; private set; }
    public String mainViabilityLayoutUrl { get; private set; }
    public String paymentMethodNoteImageUrl { get; private set; }
    public String paymentMethodLeftHtml { get; private set; }
    public String paymentMethodRightHtml { get; private set; }
    public List<String> mainViabilityStudyChunks { get; private set; }

    public PDFControllerExtension(ApexPages.StandardController controller) {
        
        this.controller = controller;
        Id opportunityId = (Id)controller.getId();
        // Realize uma consulta SOQL para obter todos os campos necessários da Oportunidade
        this.opportunity = [SELECT Id,
                            RecordTypeId,
                            RecordType.DeveloperName,
                            Account.Name,
                            Account.CPF__c,
                            Account.CNPJ__c,
                            EnderecoOportunidade__c,
                            Distribuidora__c,
                            TarifaEnergia__c,
                            DescontoPromocional__c,
                            DescontoFixoBowE__c,
                            Kwh__c,
                            NotePaymentMethod__c,
                            ObservacaoPagamentoEsquerdo__c,
                            ObservacaoPagamentoDireito__c,
                            TipoConexao__c,
                            CustoMensalAproximadoBowE__c,
                            EconomiaFixa__c,
                            EconomiaPromocional__c,
                            FaturaDescontoFixo__c,
                            FaturaDescontoPromocional__c,
                            EconomiaXMesesFixa__c,
                            EconomiaXMesesPromocional__c,
                            EconomiaAnualEstimada__c,
                            PrazoContratoParceiro__c,
                            GrupoTarifario__c,
                            isPromotional__c,
                            StageName,
                            Numeroproposta__c,
                            Parceiro__r.Name,
                            Parceiro__r.CapaProposta__c,
                            Parceiro__r.CapaPromocional__c,
                            TipoKitPromocional__c,
                            PropostaAlterada__c,
                            MainViability__c,
                            MainViability__r.TextStudy__c,
                            (SELECT ID, Product2.Description FROM OpportunityLineItems)
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        this.selectedCoverId = this.opportunity.Parceiro__r.CapaProposta__c;
        this.salvar = ApexPages.currentPage().getParameters().get('salvar');
        pdfUrls = new List<String>();
        if(this.opportunity.OpportunityLineItems.size() > 0) {
            this.description = this.opportunity.OpportunityLineItems[0]?.Product2.Description != null ? this.opportunity.OpportunityLineItems[0]?.Product2.Description : 'Descrição não disponível';
        }
        //Controlar recursividade na chamada de getContent()
        //salvar = ApexPages.currentPage().getParameters().get('salvar');

        // Carrega os URLs dos PDFs se não estiver salvando a página
        //if (String.isEmpty(salvar)) {
        loadPdfUrls();
        //}

        loadViabilityCostDetails();
        loadMainViabilityStudyData();
        paymentMethodLeftHtml = opportunity.ObservacaoPagamentoEsquerdo__c;
        paymentMethodRightHtml = opportunity.ObservacaoPagamentoDireito__c;
        if(String.isBlank(paymentMethodLeftHtml) && !String.isBlank(opportunity.NotePaymentMethod__c)){
            paymentMethodLeftHtml = opportunity.NotePaymentMethod__c; // fallback para dados antigos
        }
    }

    public String getLogoUrl() {

        if (opportunity.Parceiro__c == null) {
            return null;
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId =: opportunity.Parceiro__c AND ContentDocument.Title Like '%Logo%'
            LIMIT 1
        ];

        if (!links.isEmpty()) {
            Id contentDocumentId = links[0].ContentDocumentId;

            List<ContentVersion> versions = [
                SELECT Id
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (!versions.isEmpty()) {
                return '/sfc/servlet.shepherd/version/download/' + versions[0].Id;
            }
        }

        return null;
    }

    private void loadPdfUrls() {
        // Obtenha o ID da capa selecionada, por exemplo, do parâmetro da URL
        selectedCoverId = ApexPages.currentPage().getParameters().get('selectedCoverId');
        //GET OPP
    
        if (String.isNotEmpty(selectedCoverId)) {
            // Consulta para obter ContentDocumentIds
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :selectedCoverId
            ];
            Set<Id> documentIds = new Set<Id>();
            for (ContentDocumentLink docLink : docLinks) {
                documentIds.add(docLink.ContentDocument.LatestPublishedVersionId);
                if (String.isBlank(paymentMethodNoteImageUrl)
                    && (!String.isBlank(this.opportunity.NotePaymentMethod__c)
                        || !String.isBlank(this.opportunity.ObservacaoPagamentoEsquerdo__c)
                        || !String.isBlank(this.opportunity.ObservacaoPagamentoDireito__c))
                    && docLink.ContentDocument != null
                    && docLink.ContentDocument.Title == 'SEMPAGAMENTOS') {
                    paymentMethodNoteImageUrl = '/sfc/servlet.shepherd/version/download/' + docLink.ContentDocument.LatestPublishedVersionId;
                }
            }
        
            // Consulta para obter ContentVersions usando IN clause
            if (!documentIds.isEmpty()) {
                List<ContentVersion> contentVersions;
                if(this.opportunity.TipoKitPromocional__c == '6'){
                    contentVersions = [SELECT Id, Title, ContentDocumentId,ContentBodyId FROM ContentVersion WHERE id IN :documentIds AND (TipoKitPromocional__c = null OR TipoKitPromocional__c =:  this.opportunity.TipoKitPromocional__c) AND Title LIKE 'PROPOSTA%' AND Title != 'PROPOSTAB4' ORDER BY Title ];
                }else if(this.opportunity.TipoKitPromocional__c != null){
                    contentVersions = [SELECT Id, Title, ContentDocumentId,ContentBodyId FROM ContentVersion WHERE id IN :documentIds AND (TipoKitPromocional__c = null OR TipoKitPromocional__c =:  this.opportunity.TipoKitPromocional__c) AND Title LIKE 'PROPOSTA%' ORDER BY Title ];
                }else{
                    contentVersions = [SELECT Id, Title, ContentDocumentId,ContentBodyId FROM ContentVersion WHERE id IN :documentIds AND Title LIKE 'PROPOSTA%' ORDER BY Title];
                }
                
                // Mapear ContentVersions para os respectivos ContentDocumentIds
                for (ContentVersion version : contentVersions) {
                    System.debug('ContentVersion Id: ' + version.Id + ', Title: ' + version.Title);
                    String pdfUrl = '/sfc/servlet.shepherd/version/download/'+version.Id;
                    System.debug('pdfUrl ==>' + pdfUrl);
                    pdfUrls.add(pdfUrl);
                }
            }
        }
    
    }

    public Boolean getHasViabilityEnerzeeCosts(){
        return viabilityEnerzeeCostEntries != null && !viabilityEnerzeeCostEntries.isEmpty();
    }

    public Boolean getHasViabilityClientCosts(){
        return viabilityClientCostEntries != null && !viabilityClientCostEntries.isEmpty();
    }

    public Boolean getShouldRenderMainViabilityStudy(){
        return mainViabilityStudyChunks != null && !mainViabilityStudyChunks.isEmpty();
    }

    public Boolean getHasMainViabilityLayout(){
        return !String.isBlank(mainViabilityLayoutUrl);
    }

    public Integer getMainViabilityChunkCount(){
        return getMainViabilityStudyChunks().size();
    }

    public PageReference salvarPDF() {
        String skipAutoSave = ApexPages.currentPage().getParameters().get('skipAutoSave');
        if ('true'.equalsIgnoreCase(skipAutoSave)) {
            return null;
        }

        // Evita recursão ao chamar getContent() dentro do mesmo request
        if (salvar == 'Não') {
            return null;
        }

        // Marca para não reentrar novamente neste request
        ApexPages.PageReference refPagina = ApexPages.currentPage();
        refPagina.getParameters().put('salvar', 'Não');

        try {
            Id idRegistroPai = ApexPages.currentPage().getParameters().get('id');
            String nomePagina = ApexPages.currentPage().getUrl().substringBetween('apex/', '?');

            Id idArquivo = salvarArquivo(idRegistroPai, nomePagina);

            // Define flags para o front-end decidir fechar/mostrar toast
            lastSaveSuccess = (idArquivo != null);
            if (lastSaveSuccess) {
            } else {
                if (String.isBlank(lastSaveMessage)) {
                    lastSaveMessage = 'Houve um erro no salvamento do arquivo. Entre em contato com o administrador do sistema.';
                }
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, lastSaveMessage));
            }

        } catch (Exception e) {
            // Loga e prepara flags/mensagem para o front-end
            Utils.createLog('PDFControllerExtension', 'salvarPDF', e);
            lastSaveSuccess = false;
            lastSaveMessage = 'Falha inesperada ao salvar o PDF.';
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, lastSaveMessage));
        }

        // O fechamento da modal e os toasts são tratados no oncomplete (JS) da página
        return null;
    }

    
    public Id salvarArquivo(String opportunityId, String pageName) {
        // Dados base
        String nomeRegistro      = this.opportunity.Numeroproposta__c + ' ' + this.opportunity.Account.Name;
        String grupoTarifario    = this.opportunity.GrupoTarifario__c;
        String capaPropostaId    = this.opportunity.Parceiro__r.CapaProposta__c;
        String capaPromocionalId = this.opportunity.Parceiro__r.CapaPromocional__c;
        Boolean isPromotional    = (this.opportunity.Parceiro__r.Name == 'Bow-e') ? true : this.opportunity.isPromotional__c;
        this.isChanged           = this.opportunity.PropostaAlterada__c;
        String parceiro          = this.opportunity.Parceiro__r.Name;

        // Capa/Template
        List<ProposalCover__c> propostas = [
            SELECT Id, Template__c, isPromotional__c
            FROM ProposalCover__c
            WHERE Id IN (:capaPropostaId, :capaPromocionalId)
            AND isPromotional__c = :isPromotional
            LIMIT 1
        ];
        if (propostas.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
                'Nenhuma capa de proposta encontrada para este parceiro/condição.'));
            return null;
        }
        String selectedCoverId = propostas[0].Id;

        // Nome do arquivo
        String nomeArquivo;
        if (grupoTarifario == 'Grupo A' || parceiro == 'Enerzee - Grupo A') {
            nomeArquivo = 'Proposta A ' + nomeRegistro;
        } else if (grupoTarifario == 'Grupo B' || parceiro == 'Enerzee - Grupo B') { // << corrigido ||
            nomeArquivo = 'Proposta B ' + nomeRegistro;
        } else {
            nomeArquivo = nomeRegistro;
        }

        // Geração do PDF e salvamento
        Blob conteudoPdf = generatePdfContent(opportunityId, selectedCoverId, pageName, false);
        Id arquivoId = savePdfFile(opportunityId, nomeArquivo, pageName, conteudoPdf, this.isChanged);

        if (arquivoId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
                'Houve um erro no salvamento do arquivo. Entre em contato com o administrador do sistema.'));
            return null;
        }

        // ---- Pós-processamento (não deve derrubar o sucesso do arquivo) ----
        try {
            Opportunity opp = new Opportunity(Id = opportunityId);
            opp.PropostaGerada__c = true;

            // isManual da URL
            String isManualParam = ApexPages.currentPage().getParameters().get('isManual');
            this.isManual = (isManualParam != null) ? Boolean.valueOf(isManualParam) : false;

            // StageName conforme regras atuais
            if (OpportunityUtils.isStatusAwaitingAcceptance(this.opportunity)) {
                opp.StageName = OpportunityUtils.STATUS_CONTRATO;
            } else if (OpportunityUtils.isStatusProposalElaboration(this.opportunity)
                    || OpportunityUtils.isStatusProposalSimulation(this.opportunity)) {
                if (OpportunityUtils.isRecordTypeSolar(this.opportunity)) {
                    // if (this.isManual) {
                        opp.StageName = OpportunityUtils.STATUS_PROPOSTA_GERADA;
                    // }
                } else if (OpportunityUtils.isRecordTypeEzeeSolarB(this.opportunity)) {
                    opp.StageName = OpportunityUtils.STATUS_ANALISE_CREDITO;
                } else {
                    opp.StageName = OpportunityUtils.STATUS_PROPOSTA_ENVIADA;
                }
            }

            if (this.isChanged) {
                opp.PropostaAlterada__c = false;
            }

            update opp;

            // Integrações isoladas para não quebrar o fluxo de sucesso do arquivo
            try {
                System.debug('testeeeeeeee  ' + opp.Id);
                IntegracaoNivelloProposta.gerandoProposta(opp.Id);
            } catch (Exception ex1) {
                Utils.createLog('PDFControllerExtension', 'IntegracaoNivelloProposta', ex1);
            }

            if (this.isChanged) {
                try {
                    ProposalService.updateOpportunityPhase(new Set<Id>{ opp.Id });
                } catch (Exception ex2) {
                    Utils.createLog('PDFControllerExtension', 'ProposalService.updateOpportunityPhase', ex2);
                }
            }

        } catch (Exception postEx) {
            // Loga problemas no pós-processamento sem afetar o salvamento do arquivo
            Utils.createLog('PDFControllerExtension', 'salvarArquivo.posProcessamento', postEx);
        }

        return arquivoId;
    }


    // Método para salvar arquivo com tratamento de exceção
    public static Id savePdfFile(Id opportunityId, String numeroProposta, String nomePagina, Blob conteudoPdf, Boolean isChanged) {
        try {
            DateTime today = DateTime.Now();
            String dateString = today.day() + '-' + today.month() + '-' + today.year();
            String timeString = today.hour() + ':' + String.valueOf(today.minute()).leftPad(2, '0');

            String nomeArquivo =  numeroProposta + '-' + dateString +' '+ timeString + '.pdf';
            ContentVersion cv = new ContentVersion();
            cv.ContentLocation = 'S';
            cv.FirstPublishLocationId = opportunityId;
            cv.VersionData = conteudoPdf;
            cv.Title = numeroProposta + '-' + dateString +' '+ timeString;
            cv.PathOnClient = nomeArquivo;
            cv.NomePaginaPDF__c = nomePagina;
            cv.IsProposal__c = true;
            
            insert cv;
            return cv.Id;
        } catch (Exception e) {
            Utils.createLog('PDFControllerExtension', 'savePdfFile', e);
            return null;
        }
    }

    public static Blob generatePdfContent(Id opportunityId, Id capaPropostaId, String pageName, Boolean isAsync) {

        if (Test.isRunningTest()) {
            return Blob.valueOf('TESTE CONTEUDO PDF');
        }

        // Se for chamada síncrona, use a lógica atual
        if (!isAsync) {
            ApexPages.PageReference refPagina = ApexPages.currentPage();
            if(!Test.isRunningTest()){
                return refPagina.getContent();
            } else {
                return Blob.valueOf('TESTE CONTEUDO PDF');
            }
        }
        System.DEBUG('--------------------------------- generatePdfContent ---------------------------------------');
        System.DEBUG('opportunityId ==> ' + opportunityId);
        System.DEBUG('capaPropostaId ==> ' + capaPropostaId);
        System.DEBUG('pageName ==> ' + pageName);
        PageReference pdfPage = new PageReference('/apex/' + pageName);
        pdfPage.getParameters().put('id', opportunityId);
        pdfPage.getParameters().put('selectedCoverId', capaPropostaId);
        pdfPage.getParameters().put('skipAutoSave', 'true');

        try {
            return pdfPage.getContent();
        } catch (Exception e) {
            Utils.createLog('PDFControllerExtension', 'generatePdfContent', e);
            return null;
        }
    }
    
    // Método para determinar os nomes de registro e arquivo
    /*private static Map<String, String> determineFileNames(Id opportunityId, String descricao) {
        Map<String, String> fileNames = new Map<String, String>();
        String nomeRegistro;
        String nomeArquivo;

        if(opportunityId.getSObjectType() == Opportunity.SObjectType){
            Opportunity opp = [SELECT Name,Numeroproposta__c, account.Name FROM Opportunity WHERE Id = :opportunityId];
            nomeRegistro = opp.Numeroproposta__c + ' ' + opp.Account.Name;
        } else {
            // Lógica para outros tipos de registros, se necessário
            nomeRegistro = 'DefaultName';
        }

        if(descricao == 'ModeloPropostaA'){
            nomeArquivo = 'Proposta A ' + nomeRegistro;
        } else if(descricao == 'ModeloPropostaB'){
            nomeArquivo = 'Proposta B ' + nomeRegistro;
        } else if(descricao == 'ModeloPropostaEzeeConnect' || descricao == 'ModeloPropostaBowe') {
            nomeArquivo = nomeRegistro;
        } else {
            nomeArquivo = descricao + ' ' + nomeRegistro;
        }

        fileNames.put('nomeRegistro', nomeRegistro);
        fileNames.put('nomeArquivo', nomeArquivo);

        return fileNames;
    }*/

    // Executor central: usado pelo Queueable e pelo @future (fallback)
    private static void savePdfFileAsyncInternal(Id opportunityId, Boolean autoIntegrate, Boolean forceNewFile) {
        System.debug('--------------------------------- savePdfFileAsyncInternal ---------------------------------------');
        
        if(OpportunityBO.skipAsyncProposalGeneration == true){
            System.debug('savePdfFileAsyncInternal abortado: skipAsyncProposalGeneration == true');
            return;
        }
        if (processingOpps.contains(opportunityId)) {
            System.debug('savePdfFileAsyncInternal abortado: já em processamento para opp ' + opportunityId);
            return;
        }
        processingOpps.add(opportunityId);
        System.debug('savePdfFileAsyncInternal start for opp: ' + opportunityId + ' autoIntegrate=' + autoIntegrate + ' forceNewFile=' + forceNewFile);
        Opportunity opp = [
            SELECT Id, Name, GrupoTarifario__c, isPromotional__c,TipoKitPromocional__c, Numeroproposta__c, Distribuidora__c, Account.Name, Parceiro__r.Name, Parceiro__c, Parceiro__r.CapaProposta__c, Parceiro__r.CapaPromocional__c,RecordType.DeveloperName, RecordTypeId, ViabilityStudyFinished__c, IdVirtualOffice__c, PropostaGerada__c, ReadequacaoSolicitada__c, StageName
            FROM Opportunity 
            WHERE Id =: opportunityId
            FOR UPDATE
        ];

        // Se já marcada como gerada e não é readequação, apenas garante estágio e sai
        if (!forceNewFile && opp.PropostaGerada__c == true && opp.ReadequacaoSolicitada__c != true) {
            try {
                String stageToSet;
                if (OpportunityUtils.isStatusAwaitingAcceptance(opp)) {
                    stageToSet = OpportunityUtils.STATUS_CONTRATO;
                } else if (OpportunityUtils.isStatusProposalElaboration(opp)
                        || OpportunityUtils.isStatusProposalSimulation(opp)) {
                    if (OpportunityUtils.isRecordTypeSolar(opp)) {
                        stageToSet = OpportunityUtils.STATUS_PROPOSTA_GERADA;
                    } else if (OpportunityUtils.isRecordTypeEzeeSolarB(opp)) {
                        stageToSet = OpportunityUtils.STATUS_ANALISE_CREDITO;
                    } else {
                        stageToSet = OpportunityUtils.STATUS_PROPOSTA_ENVIADA;
                    }
                }
                if (stageToSet != null && opp.StageName != stageToSet) {
                    System.debug('savePdfFileAsyncInternal early-exit: ajustando stage existente para ' + stageToSet);
                    update new Opportunity(Id = opp.Id, StageName = stageToSet);
                }
            } catch (Exception eEarly) {
                Utils.createLog('PDFControllerExtension', 'savePdfFileAsyncInternal.earlyExit', eEarly);
            }
            processingOpps.remove(opportunityId);
            return;
        }

        // if((opp.Distribuidora__c == null || opp.Distribuidora__c == '') && opp.RecordType.DeveloperName == 'EzeeConnect') {
        //     return;
        // }

        String produto        	 = opp.RecordType.DeveloperName;
        String parceiro       	 = opp.Parceiro__r.Name;
        String grupoTarifario 	 = opp.GrupoTarifario__c;
        String nomeRegistro   	 = opp.Numeroproposta__c + ' ' + opp.Account.Name;
        String capaPropostaId 	 = opp.Parceiro__r.CapaProposta__c;
        String capaPromocionalId = opp.Parceiro__r.CapaPromocional__c;
        Boolean isPromotional    = opp.Parceiro__r.Name == 'Bow-e' ? true : opp.TipoKitPromocional__c != null ? true : false;
        String capaId;
        String nomeArquivo;
        String pageName;

        ProposalCover__c proposta = [
            SELECT Id, Template__c, isPromotional__c
            FROM ProposalCover__c
            WHERE Id IN (:capaPropostaId,:capaPromocionalId)
            AND isPromotional__c =: isPromotional
            LIMIT 1
        ];

        if (proposta.Template__c != null) {
            capaId = proposta.Id;
            pageName = proposta.Template__c;

            String baseLabel = opp.ViabilityStudyFinished__c ? 'Readequacao' : 'Proposta';
            if (grupoTarifario == 'Grupo A' || produto == 'EzeeSolarA') {
                nomeArquivo = baseLabel + ' A ' + nomeRegistro;
            } else if (grupoTarifario == 'Grupo B' || produto == 'EzeeSolarB') {
                nomeArquivo = baseLabel + ' B ' + nomeRegistro;
            } else {
                nomeArquivo = baseLabel + ' ' + nomeRegistro;
            }

        } else {
            pageName    = 'DefaultDescricao';
            nomeArquivo = pageName + ' ' + nomeRegistro;
        }

        // Evita duplicidade: se já existe proposta (IsProposal__c), apenas garante flag e integração.
        Integer existingCount = [
            SELECT COUNT()
            FROM ContentVersion
            WHERE FirstPublishLocationId = :opportunityId
                  AND IsProposal__c = true
        ];
        System.debug('savePdfFileAsyncInternal existing proposal count: ' + existingCount + ' | PropostaGerada__c=' + opp.PropostaGerada__c + ' | ReadequacaoSolicitada__c=' + opp.ReadequacaoSolicitada__c);
        if (!forceNewFile && (existingCount > 0 || (opp.PropostaGerada__c == true && opp.ReadequacaoSolicitada__c != true))) {
            try {
                Opportunity oppUpdate = new Opportunity(Id = opportunityId, PropostaGerada__c = true);
                String stageToSet;
                if (OpportunityUtils.isStatusAwaitingAcceptance(opp)) {
                    stageToSet = OpportunityUtils.STATUS_CONTRATO;
                } else if (OpportunityUtils.isStatusProposalElaboration(opp)
                        || OpportunityUtils.isStatusProposalSimulation(opp)) {
                    if (OpportunityUtils.isRecordTypeSolar(opp)) {
                        stageToSet = OpportunityUtils.STATUS_PROPOSTA_GERADA;
                    } else if (OpportunityUtils.isRecordTypeEzeeSolarB(opp)) {
                        stageToSet = OpportunityUtils.STATUS_ANALISE_CREDITO;
                    } else {
                        stageToSet = OpportunityUtils.STATUS_PROPOSTA_ENVIADA;
                    }
                }
                if (stageToSet != null) {
                    oppUpdate.StageName = stageToSet;
                }
                System.debug('savePdfFileAsyncInternal existing file - updating opp with stage: ' + stageToSet);
                update oppUpdate;
            } catch (Exception eFlag) {
                Utils.createLog('PDFControllerExtension', 'savePdfFileAsync.setFlagExisting', eFlag);
            }
            if (autoIntegrate == true) {
                try {
                    System.debug('savePdfFileAsyncInternal calling integration (existing file) for opp: ' + opportunityId);
                    IntegracaoNivelloProposta.gerandoProposta(opportunityId);
                } catch (Exception eIntExisting) {
                    Utils.createLog('PDFControllerExtension', 'savePdfFileAsyncInternal.IntegracaoExisting', eIntExisting);
                }
            }
            processingOpps.remove(opportunityId);
            return;
        }

        Blob conteudoPdf = generatePdfContent(opportunityId, capaId, pageName, true);

        if (conteudoPdf == null) {
            processingOpps.remove(opportunityId);
            return;
        }

        Id arquivoId = savePdfFile(opportunityId, nomeArquivo, pageName, conteudoPdf, false);
        System.debug('savePdfFileAsyncInternal arquivoId: ' + arquivoId);

        if (arquivoId != null) {
            try {
                Opportunity oppUpdate = new Opportunity(Id = opportunityId, PropostaGerada__c = true);
                // Avança o estágio conforme regras já usadas no fluxo manual
                String stageToSet;
                if (OpportunityUtils.isStatusAwaitingAcceptance(opp)) {
                    stageToSet = OpportunityUtils.STATUS_CONTRATO;
                } else if (OpportunityUtils.isStatusProposalElaboration(opp)
                        || OpportunityUtils.isStatusProposalSimulation(opp)) {
                    if (OpportunityUtils.isRecordTypeSolar(opp)) {
                        stageToSet = OpportunityUtils.STATUS_PROPOSTA_GERADA;
                    } else if (OpportunityUtils.isRecordTypeEzeeSolarB(opp)) {
                        stageToSet = OpportunityUtils.STATUS_ANALISE_CREDITO;
                    } else {
                        stageToSet = OpportunityUtils.STATUS_PROPOSTA_ENVIADA;
                    }
                }
                if (stageToSet != null) {
                    oppUpdate.StageName = stageToSet;
                }
                System.debug('savePdfFileAsyncInternal new file - updating opp with stage: ' + stageToSet);
                update oppUpdate;
            } catch (Exception e) {
                Utils.createLog('PDFControllerExtension', 'savePdfFileAsync.updateOpp', e);
            }
            if (autoIntegrate == true) {
                try {
                    System.debug('savePdfFileAsyncInternal calling integration (new file) for opp: ' + opportunityId);
                    IntegracaoNivelloProposta.gerandoProposta(opportunityId);
                } catch (Exception eInt) {
                    Utils.createLog('PDFControllerExtension', 'savePdfFileAsyncInternal.IntegracaoNivelloProposta', eInt);
                }
            }
        }
        processingOpps.remove(opportunityId);

    }

    @Future(callout=true)
    public static void savePdfFileAsync(Id opportunityId, Boolean autoIntegrate) {
        // Mantido como fallback, mas preferir enfileirar SavePdfJob.
        savePdfFileAsyncInternal(opportunityId, autoIntegrate, false);
    }

    public class SavePdfJob implements Queueable, Database.AllowsCallouts {
        private Id oppId;
        private Boolean autoIntegrate;
        private Boolean forceNewFile;
        public SavePdfJob(Id opportunityId, Boolean autoIntegrate, Boolean forceNewFile) {
            this.oppId = opportunityId;
            this.autoIntegrate = autoIntegrate;
            this.forceNewFile = forceNewFile;
        }
        public void execute(QueueableContext ctx) {
            savePdfFileAsyncInternal(oppId, autoIntegrate, forceNewFile);
        }
    }

    public List<SelectOption> getActiveCovers() {
        List<SelectOption> options = new List<SelectOption>();

        String capaPropostaId = this.opportunity.Parceiro__r.CapaProposta__c;
        String capaPromocionalId = this.opportunity.Parceiro__r.CapaPromocional__c;

        options.add(new SelectOption('', '-- Selecione --'));
        for (ProposalCover__c cover : [SELECT Id, Name FROM ProposalCover__c WHERE IsActive__c = true AND Id IN (:capaPropostaId,:capaPromocionalId)]) {
            options.add(new SelectOption(cover.Id, cover.Name));
        }

        return options;
    }
    
    /*private static String findDefaultCoverForOpportunity(String grupoTarifario, Boolean isPromotional, String grupoProdutos) {
        List<ProposalCover__c> defaultCovers = [SELECT Id FROM ProposalCover__c WHERE IsDefault__c = true AND GrupoDeProdutos__c =: grupoProdutos AND GrupoTarifario__c =: grupoTarifario AND isPromotional__c =: isPromotional LIMIT 1];
        return (!defaultCovers.isEmpty()) ? defaultCovers[0].Id : null;
    }*/
    
    /*private static String getProductGroup(Id recordTypeId) {
        Set<Id> ezeeConnectRecordTypes = new Set<Id>{
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('BowE').getRecordTypeId(),
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Nextron').getRecordTypeId(),
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Origo').getRecordTypeId(),
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Raizen').getRecordTypeId(),
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Simplifica').getRecordTypeId(),
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeConnect_Solled').getRecordTypeId(),
            Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Ultragaz').getRecordTypeId()
        };
    
        return ezeeConnectRecordTypes.contains(recordTypeId) ? 'Ezee Connect' : '';
    }*/
    

    public static Boolean hasKit(Opportunity opportunity) {
        List<OpportunityLineItem> lineItems = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :opportunity.Id];
        return !lineItems.isEmpty();
    }


    public static void createAddContextIdToEndpointMap(Map<Integer, Set<Id>> endpointIdToContextIds, Integer key, Id opportunityId){
        if(!endpointIdToContextIds.containsKey(key)){
            endpointIdToContextIds.put(key, new Set<Id>());
        }
        endpointIdToContextIds.get(key).add(opportunityId);
    }

        public String formatCurrencyBR(Decimal value) {
            if (value == null) return '-';
            String str = String.valueOf(value.setScale(2));
            List<String> parts = str.split('\\.');
            String intPart = parts[0];
            String decPart = parts.size() > 1 ? parts[1] : '00';

            // Formata milhar
            String formattedInt = '';
            Integer len = intPart.length();
            Integer count = 0;
            for (Integer i = len - 1; i >= 0; i--) {
                formattedInt = intPart.substring(i, i + 1) + formattedInt;
                count++;
                if (count == 3 && i != 0) {
                    formattedInt = '.' + formattedInt;
                    count = 0;
                }
            }
            return 'R$ ' + formattedInt + ',' + decPart;
        }
        public String getTarifaFormatada() {
            return formatCurrencyBR(this.opportunity.TarifaEnergia__c);
        }

        public String getCustoMensalFormatado() {
            return formatCurrencyBR(this.opportunity.CustoMensalAproximadoBowE__c);
        }

        public String getEconomiaPromocionalFormatada() {
            return formatCurrencyBR(this.opportunity.EconomiaPromocional__c);
        }

        public String getEconomiaFixaFormatada() {
            return formatCurrencyBR(this.opportunity.EconomiaFixa__c);
        }

        public String getFaturaPromocionalFormatada() {
            return formatCurrencyBR(this.opportunity.FaturaDescontoPromocional__c);
        }

        public String getFaturaFixaFormatada() {
            return formatCurrencyBR(this.opportunity.FaturaDescontoFixo__c);
        }

        public String getEconomiaXMesesPromocionalFormatada() {
            return formatCurrencyBR(this.opportunity.EconomiaXMesesPromocional__c);
        }

        public String getEconomiaXMesesFixaFormatada() {
            return formatCurrencyBR(this.opportunity.EconomiaXMesesFixa__c);
        }

        public String getEconomiaAnualFormatada() {
            return formatCurrencyBR(this.opportunity.EconomiaAnualEstimada__c);
        }

        private void loadViabilityCostDetails(){
            viabilityEnerzeeCostEntries = new List<String>();
            viabilityClientCostEntries = new List<String>();

            if(this.opportunity == null){
                return;
            }

            List<ViabilityStudy__c> viabilityList = [
                SELECT  AdequacyCostEnerzee__c,
                        AdequacyCostClient__c,
                        AcBranchCost__c,
                        DcBranchCost__c,
                        StandardAdequacyCost__c,
                        AdditionalCost__c,
                        OtherCosts__c,
                        OtherCostsDescription__c,
                        CoberturaCost__c,
                        StruturalReport__c
                FROM    ViabilityStudy__c
                WHERE   Opportunity__c = :this.opportunity.Id
                ORDER BY CreatedDate DESC
                LIMIT   1
            ];

            if(viabilityList.isEmpty()){
                return;
            }

            ViabilityStudy__c viability = viabilityList[0];

            viabilityEnerzeeCostEntries = buildViabilityCostEntries(viability.AdequacyCostEnerzee__c, viability);
            viabilityClientCostEntries = buildViabilityCostEntries(viability.AdequacyCostClient__c, viability);
        }

        private List<String> buildViabilityCostEntries(String multiSelectValues, ViabilityStudy__c viability){
            List<String> entries = new List<String>();
            for(String label : splitMultiSelectValues(multiSelectValues)){
                String displayLabel = resolveViabilityCostLabel(label, viability);
                Decimal amount = resolveViabilityCostAmount(label, viability);
                if(amount != null){
                    entries.add(displayLabel + ' (' + formatCurrencyBR(amount) + ')');
                } else {
                    entries.add(displayLabel);
                }
            }
            return entries;
        }

        private String resolveViabilityCostLabel(String label, ViabilityStudy__c viability){
            if(String.isBlank(label)){
                return label;
            }

            String normalized = label.trim().toLowerCase();
            if((normalized == 'outros custos' || normalized == 'outros custo') &&
                viability != null && !String.isBlank(viability.OtherCostsDescription__c)){
                return viability.OtherCostsDescription__c.trim();
            }

            return label;
        }

        private List<String> splitMultiSelectValues(String values){
            List<String> results = new List<String>();
            if(String.isBlank(values)){
                return results;
            }

            for(String value : values.split(';')){
                String trimmed = value != null ? value.trim() : null;
                if(!String.isBlank(trimmed)){
                    results.add(trimmed);
                }
            }

            return results;
        }

        private Decimal resolveViabilityCostAmount(String label, ViabilityStudy__c viability){
            if(viability == null || String.isBlank(label)){
                return null;
            }

            String normalized = label.trim().toLowerCase();

            Decimal amount;
            if(normalized == 'ramal cc'){
                amount = viability.DcBranchCost__c;
            } else if(normalized == 'ramal ca'){
                amount = viability.AcBranchCost__c;
            } else if(normalized == 'adequação padrão' || normalized == 'adequacao padrao'){
                amount = viability.StandardAdequacyCost__c;
            } else if(normalized == 'cobertura'){
                amount = viability.CoberturaCost__c;
            } else if(normalized == 'laudo estrutural'){
                amount = viability.StruturalReport__c;
            } else if(normalized == 'outros custos' || normalized == 'outros custos'){
                amount = viability.OtherCosts__c;
                label = viability.OtherCostsDescription__c != null ? viability.OtherCostsDescription__c.trim().toLowerCase() : 'outros custos';
            } else if(normalized == 'custos adicionais' || normalized == 'custos adicionais'){
                amount = viability.AdditionalCost__c;
            }else{
                amount = null;
            }
            if(amount != null && amount != 0){
                return amount;
            }
            return null;
        }

        private void loadMainViabilityStudyData(){
            mainViabilityStudyText = null;
            mainViabilityLayoutUrl = null;
            mainViabilityStudyChunks = new List<String>();

            if(this.opportunity == null || this.opportunity.MainViability__c == null){
                return;
            }

            if(this.opportunity.MainViability__r != null){
                mainViabilityStudyText = this.opportunity.MainViability__r.TextStudy__c;
            }

            if(mainViabilityStudyText == null){
                try{
                    ViabilityStudy__c viabilityRecord = [
                        SELECT TextStudy__c
                        FROM ViabilityStudy__c
                        WHERE Id = :this.opportunity.MainViability__c
                        LIMIT 1
                    ];
                    mainViabilityStudyText = viabilityRecord != null ? viabilityRecord.TextStudy__c : null;
                } catch (Exception ex){
                    mainViabilityStudyText = null;
                }
            }

            if(String.isBlank(mainViabilityStudyText)){
                return;
            }

            mainViabilityLayoutUrl = resolveViabilityLayoutUrl(this.opportunity.MainViability__c);
            buildMainViabilityStudyChunks();
        }

        private void buildMainViabilityStudyChunks(){
            if(String.isBlank(mainViabilityStudyText)){
                return;
            }

            final Integer maxCharsPerPage = 2200;
            String remaining = mainViabilityStudyText.trim();

            while(!String.isBlank(remaining)){
                if(remaining.length() <= maxCharsPerPage){
                    mainViabilityStudyChunks.add(remaining);
                    break;
                }

                Integer splitIndex = findBestSplitPosition(remaining, maxCharsPerPage);
                String currentChunk = remaining.substring(0, splitIndex).trim();
                if(!String.isBlank(currentChunk)){
                    mainViabilityStudyChunks.add(currentChunk);
                }
                remaining = remaining.substring(splitIndex).trim();
            }
        }

        private Integer findBestSplitPosition(String text, Integer target){
            if(String.isBlank(text)){
                return 0;
            }

            Integer length = text.length();
            if(length <= target){
                return length;
            }

            Integer upperBound = Math.min(length, target + 200);
            Integer lowerBound = Math.max(1, target - 400);
            Integer splitIndex = target;

            for(Integer i = target; i >= lowerBound; i--){
                String currentChar = text.substring(i - 1, i);
                if(currentChar == '\n' || currentChar == ' '){
                    splitIndex = i;
                    break;
                }
            }

            if(splitIndex == target){
                for(Integer i = target; i <= upperBound && i < length; i++){
                    String currentChar = text.substring(i, i + 1);
                    if(currentChar == '\n' || currentChar == ' '){
                        splitIndex = i + 1;
                        break;
                    }
                }
            }

            return Math.min(splitIndex, length);
        }

        public Integer getMainViabilityTextLineCount(){
            if(String.isBlank(mainViabilityStudyText)){
                return 0;
            }

            Integer newLineCount = mainViabilityStudyText.split('\n').size();
            return Math.max(newLineCount, 1);
        }

        public List<String> getMainViabilityStudyChunks(){
            if(mainViabilityStudyChunks == null){
                mainViabilityStudyChunks = new List<String>();
            }
            return mainViabilityStudyChunks;
        }

        private String resolveViabilityLayoutUrl(Id viabilityId){
            if(viabilityId == null){
                return null;
            }

            List<ContentDocumentLink> links = [
                SELECT  ContentDocumentId,
                        ContentDocument.Title,
                        ContentDocument.LatestPublishedVersionId,
                        ContentDocument.CreatedDate
                FROM    ContentDocumentLink
                WHERE   LinkedEntityId = :viabilityId
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT   50
            ];

            for(ContentDocumentLink linkRecord : links){
                ContentDocument doc = linkRecord.ContentDocument;
                if(doc == null || String.isBlank(doc.Title)){
                    continue;
                }

                if(isLayoutLabel(doc.Title) && doc.LatestPublishedVersionId != null){
                    return '/sfc/servlet.shepherd/version/download/' + doc.LatestPublishedVersionId;
                }
            }

            List<Attachment> legacyLayouts = [
                SELECT  Id,
                        Name
                FROM    Attachment
                WHERE   ParentId = :viabilityId
                ORDER BY CreatedDate DESC
                LIMIT   50
            ];

            for(Attachment file : legacyLayouts){
                if(file != null && isLayoutLabel(file.Name)){
                    return '/servlet/servlet.FileDownload?file=' + file.Id;
                }
            }

            return null;
        }

        private Boolean isLayoutLabel(String value){
            if(String.isBlank(value)){
                return false;
            }

            return value.trim().toLowerCase().contains('layout');
        }

        private Decimal firstNonZero(List<Decimal> values){
            for(Decimal value : values){
                if(value != null && value != 0){
                    return value;
                }
            }
            return null;
        }


}
