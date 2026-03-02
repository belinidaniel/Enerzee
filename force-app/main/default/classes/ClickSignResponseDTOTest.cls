@isTest
public class ClickSignResponseDTOTest {
  @isTest
  static void testEnvelopeDTO() {
    ClickSignResponseDTO.Envelope envelope = new ClickSignResponseDTO.Envelope();
    envelope.data = new ClickSignResponseDTO.EnvelopeData();
    envelope.data.id = '1';
    envelope.data.type = 'envelope';
    envelope.data.attributes = new ClickSignResponseDTO.EnvelopeAttributes();
    envelope.data.attributes.name = 'Test Envelope';
    envelope.data.attributes.status = 'draft';
    envelope.data.links = new ClickSignResponseDTO.Links();
    envelope.data.links.self = 'http://example.com/envelope/1';

    System.assertEquals('1', envelope.data.id);
    System.assertEquals('envelope', envelope.data.type);
    System.assertEquals('Test Envelope', envelope.data.attributes.name);
    System.assertEquals('draft', envelope.data.attributes.status);
    System.assertEquals(
      'http://example.com/envelope/1',
      envelope.data.links.self
    );
  }

  @isTest
  static void testDocumentDTO() {
    ClickSignResponseDTO.Document document = new ClickSignResponseDTO.Document();
    document.data = new ClickSignResponseDTO.DocumentData();
    document.data.id = '1';
    document.data.type = 'document';
    document.data.attributes = new ClickSignResponseDTO.DocumentAttributes();
    document.data.attributes.filename = 'Test Document';
    document.data.attributes.status = 'created';
    document.data.links = new ClickSignResponseDTO.Links();
    document.data.links.self = 'http://example.com/document/1';

    System.assertEquals('1', document.data.id);
    System.assertEquals('document', document.data.type);
    System.assertEquals('Test Document', document.data.attributes.filename);
    System.assertEquals('created', document.data.attributes.status);
    System.assertEquals(
      'http://example.com/document/1',
      document.data.links.self
    );
  }

  @isTest
  static void testSignerDTO() {
    ClickSignResponseDTO.Signer signer = new ClickSignResponseDTO.Signer();
    signer.data = new ClickSignResponseDTO.SignerData();
    signer.data.id = '1';
    signer.data.type = 'signer';
    signer.data.attributes = new ClickSignResponseDTO.SignerAttributes();
    signer.data.attributes.name = 'Test Signer';
    signer.data.attributes.email = 'test@example.com';
    signer.data.links = new ClickSignResponseDTO.Links();
    signer.data.links.self = 'http://example.com/signer/1';

    System.assertEquals('1', signer.data.id);
    System.assertEquals('signer', signer.data.type);
    System.assertEquals('Test Signer', signer.data.attributes.name);
    System.assertEquals('test@example.com', signer.data.attributes.email);
    System.assertEquals('http://example.com/signer/1', signer.data.links.self);
  }

  @isTest
  static void testTemplateDTO() {
    ClickSignResponseDTO.Template template = new ClickSignResponseDTO.Template();
    template.data = new ClickSignResponseDTO.TemplateData();
    template.data.id = '1';
    template.data.type = 'template';
    template.data.attributes = new ClickSignResponseDTO.TemplateAttributes();
    template.data.attributes.name = 'Test Template';
    template.data.links = new ClickSignResponseDTO.Links();
    template.data.links.self = 'http://example.com/template/1';

    System.assertEquals('1', template.data.id);
    System.assertEquals('template', template.data.type);
    System.assertEquals('Test Template', template.data.attributes.name);
    System.assertEquals(
      'http://example.com/template/1',
      template.data.links.self
    );
  }

  @isTest
  static void testErrorDTO() {
    ClickSignResponseDTO.Error error = new ClickSignResponseDTO.Error();
    error.code = '400';
    error.status = 400;
    error.detail = 'Bad Request';

    System.assertEquals('400', error.code);
    System.assertEquals(400, error.status);
    System.assertEquals('Bad Request', error.detail);
  }
}
