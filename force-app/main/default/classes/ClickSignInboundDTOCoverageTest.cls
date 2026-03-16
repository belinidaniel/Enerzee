/**
 * @description       : Coverage test for all ClickSignInboundDTO properties
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ClickSignInboundDTOCoverageTest {
  @IsTest
  static void shouldCoverAllDocumentProperties() {
    ClickSignInboundDTO dto = new ClickSignInboundDTO();

    dto.document = new ClickSignInboundDTO.Document();
    dto.document.key = 'doc-key';
    dto.document.account_key = 'acc-key';
    dto.document.path = '/path/doc.pdf';
    dto.document.filename = 'documento.pdf';
    dto.document.uploaded_at = Datetime.now();
    dto.document.updated_at = Datetime.now();
    dto.document.finished_at = Datetime.now();
    dto.document.deadline_at = Datetime.now().addDays(7);
    dto.document.status = 'completed';
    dto.document.auto_close = true;
    dto.document.locale = 'pt-BR';
    dto.document.metadata = new Map<String, Object>{ 'key' => 'value' };
    dto.document.sequence_enabled = false;
    dto.document.remind_interval = 3;
    dto.document.block_after_refusal = true;
    dto.document.preview = false;

    Assert.areEqual('doc-key', dto.document.key);
    Assert.areEqual('acc-key', dto.document.account_key);
    Assert.areEqual('/path/doc.pdf', dto.document.path);
    Assert.areEqual('documento.pdf', dto.document.filename);
    Assert.isNotNull(dto.document.uploaded_at);
    Assert.isNotNull(dto.document.updated_at);
    Assert.isNotNull(dto.document.finished_at);
    Assert.isNotNull(dto.document.deadline_at);
    Assert.areEqual('completed', dto.document.status);
    Assert.isTrue(dto.document.auto_close);
    Assert.areEqual('pt-BR', dto.document.locale);
    Assert.isNotNull(dto.document.metadata);
    Assert.isFalse(dto.document.sequence_enabled);
    Assert.areEqual(3, dto.document.remind_interval);
    Assert.isTrue(dto.document.block_after_refusal);
    Assert.isFalse(dto.document.preview);
  }

  @IsTest
  static void shouldCoverAllDownloadsProperties() {
    ClickSignInboundDTO.Downloads downloads = new ClickSignInboundDTO.Downloads();
    downloads.original_file_url = 'https://original.pdf';
    downloads.signed_file_url = 'https://signed.pdf';
    downloads.signed_file_checksum = 'abc123checksum';
    downloads.ziped_file_url = 'https://zipped.zip';

    Assert.areEqual('https://original.pdf', downloads.original_file_url);
    Assert.areEqual('https://signed.pdf', downloads.signed_file_url);
    Assert.areEqual('abc123checksum', downloads.signed_file_checksum);
    Assert.areEqual('https://zipped.zip', downloads.ziped_file_url);
  }

  @IsTest
  static void shouldCoverAllSignerProperties() {
    ClickSignInboundDTO.Signer signer = new ClickSignInboundDTO.Signer();
    signer.sign_as = 'sign';
    signer.list_key = 'list-key';
    signer.key = 'signer-key';
    signer.email = 'signer@test.com';
    signer.name = 'Nome Signatário';
    signer.birthday = '1990-05-15';
    signer.created_at = Datetime.now();
    signer.documentation = '123.456.789-00';
    signer.has_documentation = true;
    signer.auths = new List<String>{ 'email', 'icp' };
    signer.selfie_enabled = true;
    signer.handwritten_enabled = false;
    signer.official_document_enabled = true;
    signer.liveness_enabled = false;
    signer.facial_biometrics_enabled = true;
    signer.communicate_by = 'email';
    signer.phone_number = '+55 11 99999-9999';
    signer.phone_number_hash = 'hashvalue';
    signer.url = 'https://sign.url';
    signer.address = 'Rua Teste, 123';
    signer.longitude = '-46.6333';
    signer.latitude = '-23.5505';

    Assert.areEqual('sign', signer.sign_as);
    Assert.areEqual('list-key', signer.list_key);
    Assert.areEqual('signer-key', signer.key);
    Assert.areEqual('signer@test.com', signer.email);
    Assert.areEqual('Nome Signatário', signer.name);
    Assert.areEqual('1990-05-15', signer.birthday);
    Assert.isNotNull(signer.created_at);
    Assert.areEqual('123.456.789-00', signer.documentation);
    Assert.isTrue(signer.has_documentation);
    Assert.areEqual(2, signer.auths.size());
    Assert.isTrue(signer.selfie_enabled);
    Assert.isFalse(signer.handwritten_enabled);
    Assert.isTrue(signer.official_document_enabled);
    Assert.isFalse(signer.liveness_enabled);
    Assert.isTrue(signer.facial_biometrics_enabled);
    Assert.areEqual('email', signer.communicate_by);
    Assert.areEqual('+55 11 99999-9999', signer.phone_number);
    Assert.areEqual('hashvalue', signer.phone_number_hash);
    Assert.areEqual('https://sign.url', signer.url);
    Assert.areEqual('Rua Teste, 123', signer.address);
    Assert.areEqual('-46.6333', signer.longitude);
    Assert.areEqual('-23.5505', signer.latitude);
  }

  @IsTest
  static void shouldCoverEventAndEventDetailProperties() {
    ClickSignInboundDTO.Event ev = new ClickSignInboundDTO.Event();
    ev.name = 'sign';
    ev.occurred_at = Datetime.now();
    ev.data = new ClickSignInboundDTO.Data();
    ev.data.signer = new ClickSignInboundDTO.Signer();
    ev.data.signer.email = 'ev@test.com';
    ev.data.signer.name = 'Ev User';

    ClickSignInboundDTO.EventDetail detail = new ClickSignInboundDTO.EventDetail();
    detail.name = 'viewed';
    detail.occurred_at = Datetime.now();
    detail.data = new Map<String, Object>{ 'ip' => '127.0.0.1' };

    Assert.areEqual('sign', ev.name);
    Assert.isNotNull(ev.occurred_at);
    Assert.areEqual('ev@test.com', ev.data.signer.email);
    Assert.areEqual('viewed', detail.name);
    Assert.isNotNull(detail.occurred_at);
    Assert.isNotNull(detail.data);
  }

  @IsTest
  static void shouldCoverTemplateProperties() {
    ClickSignInboundDTO.Template template = new ClickSignInboundDTO.Template();
    template.data = new Map<String, Object>{
      'field1' => 'value1',
      'field2' => 42
    };

    Assert.isNotNull(template.data);
    Assert.areEqual('value1', template.data.get('field1'));
  }

  @IsTest
  static void shouldCoverFullDtoWithAllNestedTypes() {
    ClickSignInboundDTO dto = new ClickSignInboundDTO();

    dto.event = new ClickSignInboundDTO.Event();
    dto.event.name = 'completed';
    dto.event.occurred_at = Datetime.now();
    dto.event.data = new ClickSignInboundDTO.Data();
    dto.event.data.signer = new ClickSignInboundDTO.Signer();
    dto.event.data.signer.email = 'full@test.com';

    dto.document = new ClickSignInboundDTO.Document();
    dto.document.key = 'full-key';
    dto.document.status = 'running';
    dto.document.downloads = new ClickSignInboundDTO.Downloads();
    dto.document.downloads.original_file_url = 'https://orig.pdf';
    dto.document.downloads.signed_file_url = 'https://sign.pdf';
    dto.document.downloads.signed_file_checksum = 'checksum';
    dto.document.downloads.ziped_file_url = 'https://zip.zip';

    dto.template = new ClickSignInboundDTO.Template();
    dto.template.data = new Map<String, Object>{ 'tag' => '{{nome}}' };

    ClickSignInboundDTO.Signer s1 = new ClickSignInboundDTO.Signer();
    s1.email = 's1@test.com';
    s1.key = 'key1';
    ClickSignInboundDTO.Signer s2 = new ClickSignInboundDTO.Signer();
    s2.email = 's2@test.com';
    s2.key = 'key2';
    dto.signers = new List<ClickSignInboundDTO.Signer>{ s1, s2 };

    ClickSignInboundDTO.EventDetail ed1 = new ClickSignInboundDTO.EventDetail();
    ed1.name = 'created';
    ed1.data = new Map<String, Object>{ 'x' => 1 };
    ed1.occurred_at = Datetime.now();
    dto.events = new List<ClickSignInboundDTO.EventDetail>{ ed1 };

    Assert.areEqual('completed', dto.event.name);
    Assert.areEqual('full@test.com', dto.event.data.signer.email);
    Assert.areEqual('full-key', dto.document.key);
    Assert.areEqual(
      'https://orig.pdf',
      dto.document.downloads.original_file_url
    );
    Assert.isNotNull(dto.template.data);
    Assert.areEqual(2, dto.signers.size());
    Assert.areEqual(1, dto.events.size());
  }
}
