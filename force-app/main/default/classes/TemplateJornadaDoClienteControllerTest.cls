@IsTest
private class TemplateJornadaDoClienteControllerTest {
  @IsTest
  static void shouldLoadTemplateAndSaveImage() {
    Task t = new Task(
      Subject = 'Teste',
      Status = 'Not Started',
      Priority = 'Normal'
    );
    insert t;

    ContentVersion cv = new ContentVersion(
      Title = 'Jornada do Cliente - ' + t.Subject,
      PathOnClient = 'jornada.png',
      VersionData = Blob.valueOf('image')
    );
    insert cv;

    ApexPages.StandardController sc = new ApexPages.StandardController(t);
    TemplateJornadaDoClienteController controller = new TemplateJornadaDoClienteController(
      sc
    );
    System.assertNotEquals(null, controller.imageURL);

    PageReference pageRef = new PageReference('/apex/templateJornadaDoCliente');
    Test.setCurrentPage(pageRef);
    System.assertNotEquals(null, controller.salvarPDF());

    String imgBase64 = TestMetadataUtils.base64('data');
    String cvId = TemplateJornadaDoClienteController.saveImage(imgBase64);
    System.assertNotEquals(null, cvId);
  }
}
