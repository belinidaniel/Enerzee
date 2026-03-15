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
