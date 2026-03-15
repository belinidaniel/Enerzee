/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ClickSignInboundDTOTest {
  @IsTest
  static void shouldDeserializePayload() {
    String jsonBody =
      '{"event":{"name":"sign","data":{"signer":{"key":"signer-key","email":"signer@test.com","name":"Signer Name","auths":["email"],"has_documentation":true}},"occurred_at":"2026-03-15T10:00:00.000Z"},' +
      '"document":{"key":"doc-key","account_key":"acc-key","path":"/contracts/doc.docx","filename":"doc.docx","uploaded_at":"2026-03-15T10:01:00.000Z","updated_at":"2026-03-15T10:02:00.000Z","finished_at":"2026-03-15T10:03:00.000Z","deadline_at":"2026-03-20T10:03:00.000Z","status":"running","auto_close":true,"locale":"pt-BR","metadata":{"contract":"123"},"sequence_enabled":true,"remind_interval":3,"block_after_refusal":false,"preview":true,"downloads":{"original_file_url":"orig","signed_file_url":"signed","signed_file_checksum":"checksum","ziped_file_url":"zip"}},' +
      '"template":{"data":{"templateId":"tpl-1"}},' +
      '"signers":[{"sign_as":"sign","list_key":"list-1","key":"s1","email":"a@b.com","name":"Signer One","birthday":"1990-01-01","created_at":"2026-03-15T10:00:00.000Z","documentation":"123","has_documentation":true,"auths":["email","sms"],"selfie_enabled":false,"handwritten_enabled":true,"official_document_enabled":true,"liveness_enabled":false,"facial_biometrics_enabled":false,"communicate_by":"email","phone_number":"5511999999999","phone_number_hash":"hash","url":"http://example.com","address":"Rua 1","longitude":"-46.6","latitude":"-23.5"}],' +
      '"events":[{"name":"document_opened","data":{"source":"web"},"occurred_at":"2026-03-15T10:05:00.000Z"}]}';
    ClickSignInboundDTO dto = (ClickSignInboundDTO) JSON.deserialize(
      jsonBody,
      ClickSignInboundDTO.class
    );

    System.assertEquals('sign', dto.event.name);
    System.assertEquals('signer-key', dto.event.data.signer.key);
    System.assertEquals('doc.docx', dto.document.filename);
    System.assertEquals('doc-key', dto.document.key);
    System.assertEquals('orig', dto.document.downloads.original_file_url);
    System.assertEquals(true, dto.document.auto_close);
    System.assertEquals(true, dto.document.sequence_enabled);
    System.assertEquals(1, dto.signers.size());
    System.assertEquals('s1', dto.signers[0].key);
    System.assertEquals('Signer One', dto.signers[0].name);
    System.assertEquals(1, dto.events.size());
    System.assertEquals('document_opened', dto.events[0].name);
  }

  @IsTest
  static void shouldInstantiateAllNestedTypes() {
    ClickSignInboundDTO dto = new ClickSignInboundDTO();
    dto.event = new ClickSignInboundDTO.Event();
    dto.event.name = 'completed';
    dto.event.data = new ClickSignInboundDTO.Data();
    dto.event.data.signer = new ClickSignInboundDTO.Signer();
    dto.event.data.signer.email = 'manual@test.com';
    dto.document = new ClickSignInboundDTO.Document();
    dto.document.downloads = new ClickSignInboundDTO.Downloads();
    dto.template = new ClickSignInboundDTO.Template();
    dto.signers = new List<ClickSignInboundDTO.Signer>{
      new ClickSignInboundDTO.Signer()
    };
    dto.events = new List<ClickSignInboundDTO.EventDetail>{
      new ClickSignInboundDTO.EventDetail()
    };

    System.assertEquals('completed', dto.event.name);
    System.assertEquals('manual@test.com', dto.event.data.signer.email);
    System.assertNotEquals(null, dto.document.downloads);
    System.assertEquals(1, dto.signers.size());
    System.assertEquals(1, dto.events.size());
  }
}
