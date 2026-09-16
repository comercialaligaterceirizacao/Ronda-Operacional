# A Liga Almoxarifado

Sistema separado do A Liga Ronda para requisição, separação, retirada e comprovante de entrega de materiais e uniformes.

## Fluxo
Celular do supervisor/inspetora -> API central -> computador do Almoxarifado -> separação -> disponível -> retirada -> assinatura -> entregue.

## Acessos iniciais
- supervisor / 1234
- almoxarifado / 1234

Trocar as senhas antes do uso real.

## Servidor no computador do Almoxarifado
1. Instale Node.js 18+.
2. Abra a pasta `server`.
3. Execute `npm start`.
4. A API ficará na porta 3000.
5. No celular, o endereço da API deve apontar para o IP do computador, por exemplo `http://192.168.0.10:3000/api`.

## APK
O GitHub Actions gera automaticamente o APK a cada alteração na branch `main`.

## Observação
O catálogo inicial foi incluído apenas como cadastro de produtos. Não existe integração automática com o controle de estoque nesta versão.
