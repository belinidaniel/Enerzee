@IsTest
private class ClickSignInboundDTOTest {
    @IsTest
    static void shouldDeserializePayload() {
        String jsonBody = '{"event":{"name":"sign","data":{"signer":{"key":"signer-key"}}},"document":{"key":"doc-key","status":"running"},"signers":[{"key":"s1","email":"a@b.com"}] }';
        ClickSignInboundDTO dto = (ClickSignInboundDTO) JSON.deserialize(jsonBody, ClickSignInboundDTO.class);

        System.assertEquals('sign', dto.event.name);
        System.assertEquals('doc-key', dto.document.key);
        System.assertEquals(1, dto.signers.size());
        System.assertEquals('s1', dto.signers[0].key);
    }
}
