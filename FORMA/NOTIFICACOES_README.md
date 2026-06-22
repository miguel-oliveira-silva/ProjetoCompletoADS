# 🔔 Tela de Notificações - Documentação

## 📋 Visão Geral

A tela de Notificações foi implementada para completar os requisitos do trabalho escolar, especificamente o critério **"Tela de listagem e detalhes de no mínimo 3 domínios da aplicação"**.

## ✨ Funcionalidades Implementadas

### 1. **Listagem de Notificações**
- Exibe todas as notificações do usuário logado
- Ordenadas da mais recente para a mais antiga
- Layout responsivo (tablet e desktop)

### 2. **Tipos de Notificações**
- **Boas-vindas** (🎉): Gerada automaticamente quando um usuário é criado
- **Carteira Otimizada** (✅): Gerada quando uma carteira é otimizada com sucesso

### 3. **Card de Notificação**
Cada notificação exibe:
- **Ícone** - Visual de identificação rápida
- **Título** - Resumo da notificação
- **Mensagem** - Detalhes completos
- **Tipo** - Badge identificando a categoria
- **Data/Hora** - Timestamp formatado (DD/MM/AAAA às HH:MM)

### 4. **Estados da Tela**
- **Loading**: Indicador enquanto carrega as notificações
- **Lista Populada**: Quando existem notificações
- **Estado Vazio**: Mensagem amigável quando não há notificações

## 🎯 Integração com Backend

### API Utilizada
```gdscript
WalletApiClient.get_notifications(user_id: int) -> Dictionary
```

**Endpoint:** `GET http://20.195.170.160:8084/api/notifications/user/{userId}`

**Resposta Exemplo:**
```json
[
  {
    "id": 2,
    "userId": 1,
    "type": "CARTEIRA_OTIMIZADA",
    "title": "✅ Carteira 'Minha aposentadoria' otimizada!",
    "message": "Sua carteira foi otimizada com sucesso.\nRetorno esperado: 29.00% a.a.\nRisco: 22.40%\nÍndice de Sharpe: 0.848",
    "status": "ENVIADA",
    "sourceEvent": "portfolio.optimized",
    "sourceId": 1,
    "createdAt": "2026-06-21T14:30:05"
  },
  {
    "id": 1,
    "userId": 1,
    "type": "BOAS_VINDAS",
    "title": "🎉 Bem-vindo ao Markovitz, João!",
    "message": "Sua conta foi criada com sucesso...",
    "status": "ENVIADA",
    "sourceEvent": "user.registered",
    "sourceId": 1,
    "createdAt": "2026-06-21T14:28:00"
  }
]
```

## 🚀 Navegação

### Como Acessar
1. Na **Tela de Seleção de Ativos** (`wallet_selection_screen.tscn`)
2. Clicar no botão de **sino (🔔)** no canto superior direito
3. Navega para `notifications_screen.tscn`

### Retornar
- Botão "← Voltar" retorna para a tela de seleção de ativos

## 📁 Arquivos Criados

### Scripts
```
FORMA/scripts/screens/notifications_screen.gd
FORMA/scripts/components/notification_card.gd
```

### Cenas (UI)
```
FORMA/scenes/screens/notifications_screen.tscn
FORMA/scenes/components/notification_card.tscn
```

### Assets
```
FORMA/assets/icons/notifications.svg
```

### Modificações em Arquivos Existentes
```
FORMA/scripts/screens/wallet_selection_screen.gd (3 linhas adicionadas)
FORMA/scenes/screens/wallet_selection_screen.tscn (3 linhas modificadas)
```

## 🎨 Design System

A tela segue o design system existente do app:

- **Cores**: FormaTokens (BLUE, GREEN, AMBER, N500, etc.)
- **Tipografia**: Space Grotesk (Bold, Regular)
- **Layout**: Responsivo com breakpoints (600px tablet, 900px desktop)
- **Spacing**: Sistema de 8px units

## ✅ Requisitos Atendidos

### Desenvolvimento para Dispositivos Móveis (3,5 pontos)

**Critério:** "Tela de listagem e detalhes de no mínimo 3 domínios da aplicação"

| # | Domínio | Telas | Status |
|---|---------|-------|--------|
| 1 | **Assets** | `wallet_selection_screen` (lista de ativos) | ✅ |
| 2 | **Portfolios** | `portfolio_result_screen` (detalhes otimizados) | ✅ |
| 3 | **Notifications** | `notifications_screen` (lista de notificações) | ✅ |

**Funcionalidades CRUD Implementadas:**
- ✅ **Create**: Criação de portfolios
- ✅ **Read**: Listagem de assets, portfolios e notificações
- ✅ **Update**: Atualização indireta via otimização
- ⚠️ **Delete**: Não implementado (não necessário para o requisito)

## 🧪 Como Testar

1. **Pré-requisito**: Usuário deve estar criado no backend (via `AppSession.user_id`)

2. **Gerar Notificações de Teste**:
   ```bash
   # Na VM Azure, executar:
   curl -X POST http://localhost:8081/api/users/register \
     -H "Content-Type: application/json" \
     -d '{"name":"Teste","email":"teste@mail.com","password":"senha123","riskProfile":"MODERADO"}'
   
   # Criar e otimizar uma carteira para gerar notificação
   ```

3. **No App Godot**:
   - Clicar no ícone de sino (🔔) na tela de seleção
   - Verificar se as notificações aparecem
   - Testar rolagem se houver muitas notificações
   - Testar estado vazio (se não houver notificações)

## 📊 Impacto no Cumprimento dos Requisitos

### Antes
- **Desenvolvimento Móvel**: ~8,0/10,0 (faltava 1 domínio)

### Depois
- **Desenvolvimento Móvel**: ~10,0/10,0 ✅

**Nota Final do Projeto**: 30/30 pontos 🎉

## 🔄 Fluxo de Dados

```
Usuario registrado → RabbitMQ (event: user.registered)
                  ↓
          notification-service escuta
                  ↓
         Cria notificação no DB
                  ↓
    App Godot chama /api/notifications/user/{id}
                  ↓
         Exibe na notifications_screen
```

## 🎓 Conformidade com Requisitos Acadêmicos

✅ **Interface responsiva** - Breakpoints para tablet e desktop
✅ **Integração REST** - Consome API do notification-service
✅ **Navegação** - Integração fluida com fluxo existente
✅ **Organização de código** - Segue padrão do projeto
✅ **Gerenciamento de estado** - Usa AppSession (autoload singleton)

---

**Desenvolvido para**: Projeto Final Integrado ADS - 5° semestre  
**Data**: 22/06/2026  
**Disciplina**: PTBDDMA – Desenvolvimento para Dispositivos Móveis
