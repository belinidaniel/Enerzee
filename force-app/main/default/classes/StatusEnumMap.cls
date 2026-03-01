public class StatusEnumMap {
  public static Map<String, Integer> SolarEnum = new Map<String, Integer>{
    'Elaboração de proposta' => 1,
    'Proposta Gerada' => 2,
    'Confirmação de pagamento sinal' => 3,
    'Viabilidade Técnica' => 4,
    'Readequação de Proposta' => 5,
    'Aguardando aceite' => 6,
    'Contrato' => 7,
    'Parecer de acesso' => 8,
    'Confirmação de pagamento contrato' => 9,
    'Ganho fechado' => 10,
    'Fechado Perdido' => 10
  };

  public static Map<String, Integer> EzeeSolarAEnum = new Map<String, Integer>{
    'Elaboração de proposta' => 11,
    'Proposta enviada' => 12,
    'Apresentação Comercial' => 13,
    'Viabilidade Técnica' => 14,
    'Readequação de Proposta' => 15,
    'Aguardando aceite' => 16,
    'Contrato' => 17,
    'Parecer de acesso' => 18,
    'Equipamento' => 18,
    'Instalação' => 18,
    'Ganho fechado' => 19,
    'Fechado Perdido' => 19
  };

  public static Map<String, Integer> EzeeSolarBEnum = new Map<String, Integer>{
    'Elaboração de proposta' => 20,
    'Análise de Crédito' => 21,
    'Informações adicionais' => 22,
    'Contrato' => 23,
    'Viabilidade Tecnica' => 24,
    'Parecer de acesso' => 25,
    'Equipamento' => 25,
    'Instalação' => 25,
    'Ganho fechado' => 26,
    'Fechado Perdido' => 26
  };

  public static Map<String, Integer> EzeeConnectEnum = new Map<String, Integer>{
    'Simulação de Proposta' => 27,
    'Proposta enviada' => 28,
    'Contrato' => 29,
    'Validação' => 30,
    'Finalizado' => 31,
    'Ganho fechado' => 32,
    'Fechado Perdido' => 32
  };

  public static Map<String, Integer> EzeeLivreEnum = new Map<String, Integer>{
    'Simulação de Proposta' => 33,
    'Proposta enviada' => 34,
    'Apresentação Comercial' => 35,
    'Negociação' => 36,
    'Contrato' => 37,
    'Ganho fechado' => 38,
    'Fechado Perdido' => 38
  };

  public static Map<String, Integer> ProdutosEnum = new Map<String, Integer>{
    'Elaboração de proposta' => 39,
    'Proposta enviada' => 40,
    'Confirmação de pagamento sinal' => 41,
    'Viabilidade Técnica' => 42,
    'Readequação de Proposta' => 43,
    'Aguardando aceite' => 44,
    'Contrato' => 45,
    'Parecer de acesso' => 46,
    'Confirmação de pagamento contrato' => 47,
    'Ganho fechado' => 48,
    'Fechado Perdido' => 48
  };

  public static Map<String, Integer> ServicosEnum = new Map<String, Integer>{
    'Elaboração de proposta' => 49,
    'Proposta enviada' => 50,
    'Contrato' => 51,
    'Confirmação de pagamento' => 52,
    'Ganho fechado' => 53,
    'Fechado Perdido' => 53
  };

  public static Map<String, Integer> ServicosEpcEnum = new Map<String, Integer>{
    'Elaboração de proposta' => 54,
    'Proposta enviada' => 55,
    'Viabilidade Técnica' => 56,
    'Contrato' => 57,
    'Confirmação de pagamento' => 58,
    'Ganho fechado' => 59,
    'Fechado Perdido' => 59
  };

  public static Map<Integer, Map<String, Integer>> pipelineSubstatusMap = new Map<Integer, Map<String, Integer>>{
    3 => new Map<String, Integer>{ 'Aguardando Pagamento' => 1, 'Pago' => 2 },
    4 => new Map<String, Integer>{
      'Agendamento de Visita' => 3,
      'Estudo de Viabilidade' => 4
    },
    7 => new Map<String, Integer>{
      'Geração do Contrato' => 5,
      'Contrato Enviado' => 6,
      'Contrato Assinado' => 7
    },
    8 => new Map<String, Integer>{
      'Fast Track' => 8,
      'Em Análise' => 9,
      'Aprovado' => 10
    },
    10 => new Map<String, Integer>{ 'Ganho' => 11, 'Perdido' => 12 },
    13 => new Map<String, Integer>{
      'Agendamento de Visita' => 13,
      'Agendado' => 14
    },
    14 => new Map<String, Integer>{
      'Aguardando Pagamento' => 15,
      'Agendamento de Visita' => 16,
      'Estudo de Viabilidade' => 17
    },
    17 => new Map<String, Integer>{
      'Aguardando Documentos' => 18,
      'Geração do Contrato' => 19,
      'Contrato Enviado' => 20,
      'Contrato Assinado' => 21
    },
    18 => new Map<String, Integer>{
      'Em Análise' => 22,
      'Aprovado' => 23,
      'Entrega de materiais' => 24,
      'Em instalação' => 25
    },
    19 => new Map<String, Integer>{ 'Ganho' => 26, 'Perdido' => 27 },
    23 => new Map<String, Integer>{
      'Geração do Contrato' => 28,
      'Contrato Enviado' => 29,
      'Contrato Assinado' => 30
    },
    25 => new Map<String, Integer>{
      'Em Análise' => 31,
      'Aprovado' => 32,
      'Entrega de materiais' => 33,
      'Em instalação' => 34
    },
    26 => new Map<String, Integer>{ 'Ganho' => 35, 'Perdido' => 36 },
    29 => new Map<String, Integer>{
      'Geração do Contrato' => 37,
      'Contrato Enviado' => 38,
      'Contrato Assinado' => 39
    },
    30 => new Map<String, Integer>{ 'Em Andamento' => 40, 'Pendência' => 41 },
    31 => new Map<String, Integer>{ 'Validando Bonificação' => 42 },
    32 => new Map<String, Integer>{ 'Ganho' => 43, 'Perdido' => 44 },
    35 => new Map<String, Integer>{ 'Em Agendamento' => 45, 'Agendado' => 46 },
    37 => new Map<String, Integer>{
      'Geração do Contrato' => 47,
      'Contrato Enviado' => 48
    },
    38 => new Map<String, Integer>{ 'Ganho' => 49, 'Perdido' => 50 },
    41 => new Map<String, Integer>{
      'Aguardando Pagamento' => 51,
      'Pago' => 52
    },
    42 => new Map<String, Integer>{
      'Agendamento de Visita' => 53,
      'Estudo de Viabilidade' => 54
    },
    45 => new Map<String, Integer>{
      'Geração do Contrato' => 55,
      'Contrato Enviado' => 56,
      'Contrato Assinado' => 57
    },
    46 => new Map<String, Integer>{
      'Fast Track' => 58,
      'Em Análise' => 59,
      'Aprovado' => 60
    },
    48 => new Map<String, Integer>{ 'Ganho' => 61, 'Perdido' => 62 },
    51 => new Map<String, Integer>{
      'Geração do Contrato' => 63,
      'Contrato Enviado' => 64,
      'Contrato Assinado' => 65
    },
    53 => new Map<String, Integer>{ 'Ganho' => 66, 'Perdido' => 67 },
    56 => new Map<String, Integer>{
      'Agendamento de Visita' => 68,
      'Estudo de Viabilidade' => 69
    },
    57 => new Map<String, Integer>{
      'Geração do Contrato' => 70,
      'Contrato Enviado' => 71,
      'Contrato Assinado' => 72
    },
    59 => new Map<String, Integer>{ 'Ganho' => 73, 'Perdido' => 74 },
    21 => new Map<String, Integer>{
      'Análise' => 75,
      'Aprovado' => 76,
      'Reprovado' => 77
    }
  };

  public static Integer getStatusEnum(
    String recordTypeName,
    String statusValue
  ) {
    Map<String, Integer> selectedEnum;

    if (recordTypeName == 'Solar') {
      selectedEnum = SolarEnum;
    } else if (recordTypeName == 'Ezee Solar - Grupo A') {
      selectedEnum = EzeeSolarAEnum;
    } else if (recordTypeName == 'Ezee Solar - Grupo B') {
      selectedEnum = EzeeSolarBEnum;
    } else if (recordTypeName == 'Ezee Connect') {
      selectedEnum = EzeeConnectEnum;
    } else if (recordTypeName == 'Ezee Livre') {
      selectedEnum = EzeeLivreEnum;
    } else if (recordTypeName == 'Produtos') {
      selectedEnum = ProdutosEnum;
    } else if (recordTypeName == 'Serviços') {
      selectedEnum = ServicosEnum;
    } else if (recordTypeName == 'Serviços EPC') {
      selectedEnum = ServicosEpcEnum;
    }

    if (selectedEnum != null && selectedEnum.containsKey(statusValue)) {
      return selectedEnum.get(statusValue);
    }
    return 0;
  }

  public static Integer getSubstatusEnum(
    Integer pipelineId,
    String substatusValue
  ) {
    if (pipelineSubstatusMap.containsKey(pipelineId)) {
      Map<String, Integer> subMap = pipelineSubstatusMap.get(pipelineId);
      if (subMap.containsKey(substatusValue)) {
        return subMap.get(substatusValue);
      }
    }
    return 0;
  }
}
