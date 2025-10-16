/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 09-09-2025
 * @last modified by  : Daniel Belini
**/
@isTest
public with sharing class PDFControllerExtensionTest {

    //Objetivo: classe de testes para a classe PDFControllerExtension
    
    @isTest
    static void testePositivoA(){
        
        ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(Template__c = 'ModeloPropostaA'), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = proposalCover.id,
            Produto__c = 'Solar'
        ), true);

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
        	Parceiro__c = parceiro.id
        ), true); 

        //Criar VFP
        test.startTest();

            ApexPages.StandardController sc = new ApexPages.StandardController(opp);
            PDFControllerExtension ext = new PDFControllerExtension(sc);
            ext.selectedCoverId = proposalCover.Id;

            PageReference pageRef = Page.PropostaContainer;
            pageRef.getParameters().put('id', String.valueOf(opp.Id));

            Test.setCurrentPage(pageRef);

            ext.salvarPDF();

        test.stopTest();

        //Avaliar o resultado
        List<ContentDocumentLink> linkResultado = [SELECT
                                                       Id, LinkedEntityId
                                                   FROM ContentDocumentLink
                                                   WHERE
                                                       LinkedEntityId = :opp.Id];


        ContentVersion resultado = [SELECT
                                        Id, FirstPublishLocationId, VersionData, NomePaginaPDF__c
                                    FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];

    }

    @isTest
    static void testePositivoB(){

        ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(Template__c = 'ModeloPropostaB'), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = proposalCover.id,
            Produto__c = 'Solar'
        ), true);

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
        	Parceiro__c = parceiro.id
        ), true);  

        //Criar VFP
        test.startTest();

            ApexPages.StandardController sc = new ApexPages.StandardController(opp);
            PDFControllerExtension ext = new PDFControllerExtension(sc);
            ext.selectedCoverId = proposalCover.Id;

            PageReference pageRef = Page.PropostaContainer;
            pageRef.getParameters().put('id', String.valueOf(opp.Id));

            Test.setCurrentPage(pageRef);

            ext.salvarPDF();

        test.stopTest();

        //Avaliar o resultado
        List<ContentDocumentLink> linkResultado = [SELECT
                                                       Id, LinkedEntityId
                                                   FROM ContentDocumentLink
                                                   WHERE
                                                       LinkedEntityId = :opp.Id];


                                                       
        ContentVersion resultado = [SELECT
                                        Id, FirstPublishLocationId, VersionData, NomePaginaPDF__c
                                    FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];




}
    
    @isTest
    static void testePositivoBowe(){

        ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(Template__c = 'ModeloPropostaBowe'), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = proposalCover.id,
            Produto__c = 'Solar'
        ), true);

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
        	Parceiro__c = parceiro.id
        ), true); 

        //Criar VFP
        test.startTest();

            ApexPages.StandardController sc = new ApexPages.StandardController(opp);
            PDFControllerExtension ext = new PDFControllerExtension(sc);
            ext.selectedCoverId = proposalCover.Id;

            PageReference pageRef = Page.PropostaContainer;
            pageRef.getParameters().put('id', String.valueOf(opp.Id));

            Test.setCurrentPage(pageRef);

            ext.salvarPDF();

        test.stopTest();

        //Avaliar o resultado
        List<ContentDocumentLink> linkResultado = [SELECT
                                                       Id, LinkedEntityId
                                                   FROM ContentDocumentLink
                                                   WHERE
                                                       LinkedEntityId = :opp.Id];


        ContentVersion resultado = [SELECT
                                        Id, FirstPublishLocationId, VersionData, NomePaginaPDF__c
                                    FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];
    }
    
    @isTest
    static void testePositivoEzeeConnect(){

        ProposalCover__c proposalCover = (ProposalCover__c) TestFactory.createSObject(new ProposalCover__c(Template__c = 'ModeloPropostaEzeeConnect'), true);
        Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(new Parceiro__c(
            CapaProposta__c = proposalCover.id,
            Produto__c = 'Solar'
        ), true);

        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
        	Parceiro__c = parceiro.id
        ), true);  

        //Criar VFP
        test.startTest();

            ApexPages.StandardController sc = new ApexPages.StandardController(opp);
            PDFControllerExtension ext = new PDFControllerExtension(sc);
            ext.selectedCoverId = proposalCover.Id;

            PageReference pageRef = Page.PropostaContainer;
            pageRef.getParameters().put('id', String.valueOf(opp.Id));

            Test.setCurrentPage(pageRef);

            ext.salvarPDF();

        test.stopTest();

        //Avaliar o resultado
        List<ContentDocumentLink> linkResultado = [SELECT
                                                       Id, LinkedEntityId
                                                   FROM ContentDocumentLink
                                                   WHERE
                                                       LinkedEntityId = :opp.Id];


        ContentVersion resultado = [SELECT
                                        Id, FirstPublishLocationId, VersionData, NomePaginaPDF__c
                                    FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id];

    }
}