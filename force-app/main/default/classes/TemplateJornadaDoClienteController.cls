global with sharing class TemplateJornadaDoClienteController {

    private ApexPages.standardController controller;
    public String imageURL {get; set;}
    public static Id taskIdCls;

    public TemplateJornadaDoClienteController(ApexPages.StandardController controller) {
        this.controller = controller;
        Id taskId = (Id)controller.getId();
        Task task = [SELECT Id, Subject FROM Task WHERE Id = :taskId];

        String templateJornada = 'Jornada do Cliente - ' + task.Subject;

        ContentVersion version = [SELECT Id FROM ContentVersion WHERE Title = :templateJornada];

        this.imageURL = '/sfc/servlet.shepherd/version/renditionDownload/' + version.Id;
    }

    public PageReference salvarPDF() {

        ApexPages.PageReference refPagina = ApexPages.currentPage();
        refPagina.getParameters().put('id', '');

        return refPagina;
    }

    public TemplateJornadaDoClienteController(){}

    @InvocableMethod(label='Create File from flow')
    global static void createFileFromFlow(List<String> inputs){
        new TemplateJornadaDoClienteController().createfile(inputs[0]);
    }

    global PageReference createfile(String taskId) {

        try {

            Task task = [SELECT Id, Subject FROM Task WHERE Id = :taskId];
            
            TemplateJornadaDoClienteController.taskIdCls = taskId;

            String templateJornada = 'Jornada do Cliente - ' + task.Subject;

            ContentVersion version = [SELECT Id FROM ContentVersion WHERE Title = :templateJornada];

            this.imageURL = 'https://enrz--dvlfabiano.sandbox.my.salesforce.com/sfc/servlet.shepherd/version/download/'  + version.Id;

            PageReference pdfPage = new PageReference('/apex/templateJornadaDoCliente');
            pdfPage.getParameters().put('id', taskId);
            pdfPage.getParameters().put('imageURL', this.imageURL);
            
            pdfPage.getContent();

            return pdfPage;

            /*ContentVersion cv = new ContentVersion();
            cv.ContentLocation = 'S';
            cv.VersionData = fileContent;
            cv.Title = task.Subject;
            cv.PathOnClient = task.Subject + '.pdf';

            insert cv;

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            cdl.LinkedEntityId = taskId;
            insert cdl;

            ContentDistribution cd = new ContentDistribution();
            cd.Name = task.Subject;
            cd.ContentVersionId = cv.id;
            cd.PreferencesAllowViewInBrowser = true;
            cd.PreferencesLinkLatestVersion = true;
            cd.PreferencesNotifyOnVisit = false;
            cd.PreferencesPasswordRequired = false;
            cd.PreferencesAllowOriginalDownload = true;
            insert cd;

            cd = [SELECT Id, DistributionPublicUrl, ContentDownloadURL FROM ContentDistribution WHERE Id = :cd.Id];

            return cd.ContentDownloadURL;
            return '';*/

        } catch (Exception e) {
            Utils.createLog('PDFControllerExtension', 'generatePdfContent', e);
            return null;
        }
    }

    @RemoteAction 
    public static String saveImage(String imageBody) {
        Task task = [SELECT Id, Subject FROM Task LIMIT 1];
        System.debug('this.taskId' + TemplateJornadaDoClienteController.taskIdCls);
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.VersionData = EncodingUtil.base64Decode(imageBody);
        cv.Title = task.Subject;
        cv.PathOnClient = task.Subject + '.png';

            insert cv;
        System.debug('imageBody' + imageBody);
        //Attachment a = new Attachment(ParentId = [SELECT Id FROM Task LIMIT 1].Id, name='Image.png', ContentType='image/png', Body=EncodingUtil.base64Decode(imageBody));
        //insert a;

        return cv.Id;
    }
}