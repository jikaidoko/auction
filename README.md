# TRABAJO PRÁCTICO
## *Fundamentos de Solidity*
### ETH Kipu Módulo 2

#### *Instrucciones de uso*
###### - 📦 Constructor:
###### Al desplegar el contrato se define el propietario de la subasta.
###### Es el encargado de dar inicio a la misma mediante la función *openAuction()* en la que debe definir la duración y el tiempo extra de la subasta en el caso de recibir ofertas minutos antes del cierre.
###### - 🏷️ Función para ofertar
###### La función *newBid()* permite realizar la puja 
###### La nueva oferta es válida si:
- Es mayor en al menos 5% que la mayor oferta actual.
- Se realiza mientras la subasta está activa.
- No debe realizarla el propietario de la subasta.
- No puede volver a ofertar el mayor oferente (debe esperar a que su oferta sea superada por otro)

###### - 🥇 Mostrar ganador
###### - La función *publishWinner()* devuelve la dirección del oferente ganador y el valor de la oferta ganadora.
###### - 📜 Mostrar ofertas
###### - La función *publishBids()* devuelve la lista de oferentes y sus respectivos montos ofrecidos.
###### - 💸 Devolver depósitos
###### - La función *returnMoney()* devuelve el depósito a los oferentes no ganadores al finalizar la subasta (Se descuenta una comisión del 2%).
###### - 🚀 Funcionalidades Avanzadas
###### - 🔁 Reembolso parcial. Durante la subasta, los participantes pueden retirar el importe por encima de su última oferta válida mediante la función *refundPreviousBids()*.


###### Ejemplo:
| Tiempo  | Usuario  | Oferta  |
| ------------ | ------------ | ------------ |
| T0   | Usuario 1  | 1 ETH  |
|  T1 | Usuario 2  | 2 ETH   |
| T2  | Usuario 1  | 3 ETH   |

###### → Usuario 1 puede pedir el reembolso de la oferta T0 (1 ETH).

------------
###### 💰 Manejo de depósitos
###### Las ofertas son depositadas en el contrato con la función payable *newBid()*.
###### Están asociadas a las direcciones de los oferentes en un struct denominado *AuctionStruct*. Este se guarda en un array que permite tener un seguimiento de todas las ofertas realizadas.
------------
###### 📢 Eventos del contrato
- Subasta Iniciada: Emitido cuando el propietario lanza la subasta.
- Nueva Oferta: Emitido cuando se realiza una nueva oferta.
- Tiempo Extra: Emitido cuando una oferta se realiza en los últimos 10 minutos y se añade tiempo extra para seguir ofertando.
- Subasta Finalizada: Emitido cuando finaliza la subasta.
_____________
_____________

##### Detalles del código:
##### *Subasta avanzada*
La versión final del contrato procura cumplir con las todas funciones requeridas en el trabajo práctico, tanto las básicas como las avanzadas.
Posee una función específica para iniciar la subasta. Está restringida al propietario del contrato y solicita los parámetros de la duración del contrato y del tiempo extra que se asigna: 
```
function openAuction(uint256 _timeLimit, uint256 _extratime) public onlyOwner returns (bool) {
        require(startAuction == false, "La subasta ya ha iniciado");
        startTime = block.timestamp;
        timeLimit= startTime + _timeLimit;
        extratime = _extratime;
        //emitimos un alerta para informar la apertura de la subasta
        emit StartAuction(string (auctionStarted));
        return startAuction = true;
    }
```


La función payable **newBid()** es el método principal para poder realizar las nuevas ofertas de la subasta:
```
function newBid() public payable {}
```
Posee varias condiciones para poder ejecutarse, algunas requeridas en la consigna y otras que pueden colaborar con mejorar la infraestructura de la subasta.

El modificador **auctionIsOpen()**, válido para todas las acciones que deben realizarse durante la duración de la subasta, por supuesto condiciona la posibilidad de ofertar.

El modificador **notOwner()** no es requerido por la consigna, pero evita que el propietario del contrato tenga la posibilidad de participar en la subasta, lo que le agrega más transparencia a la misma.

El modificador **notTopBidder()** tampoco es parte de la consigna, pero también aporta mayor coherencia a la dinámica de las ofertas, porque le impide al mayor oferente seguir ofertando sobre su última propuesta, evitando un posible bloqueo de la participación de los demás.

La consigna solicita que **las nuevas ofertas superen a la oferta anterior en un 5 por ciento**:

```
    function newBid() public payable notOwner auctionIsOpen notTopBidder {
        require(msg.value!= 0 && msg.value > highestBid + highestBid*5/100,
        "La nueva oferta debe superar al menos un 5 por ciento a la oferta anterior");
}
```
La nueva oferta **emite un alerta** con la dirección del oferente y el monto asociado, tal como solicitaba la consigna:
```
emit Bid(msg.sender, highestBid);
```
También hay una condición, dentro de la función **newBid()** solicitada por la consigna, para **añadir un tiempo extra** si se realiza una oferta en los últimos diez minutos:
```
if (timeLimit - block.timestamp < 10 minutes){
            newTimeLimit = timeLimit + extratime;
            //Sumamos el tiempo extra y se lo asignamos al tiempo límite
            timeLimit = newTimeLimit;
            //emitimos un alerta para informar que se ha añadido tiempo extra
            emit ExtraTime (string (extraTime)); 
        }
```
La función **publishWinner()** se encarga de publicar al ganador de la subasta:
```
        function publishWinner() public view returns (address , uint256){
            return (auctList[auctList.length-1].biddingAddress, 
            auctList[auctList.length-1].amount);
        }
```
Hay una función para cerrar la subasta. El sentido que tiene es obligar al propietario del contrato a ejecutarla para habilitar las funciones que requieren que la subasta haya terminado.
```
    function closeAuction() public onlyOwner returns (bool _endAuction) {
    if (block.timestamp>=timeLimit+extratime){
                return endAuction=true;
    }
    emit EndAuction(string (auctionFinished));
    }
```
Esta función emite un alerta **auctionFinished**, anunciando que "la subasta a finalizado".
El modificador **auctionIsClosed()** habilita las funciones reservadas para el final de la subasta. 
```
        function publishBids() public view returns (AuctionStruct[] memory) {
            return auctList;
        }
```

La función de devolver el dinero de las ofertas no ganadoras **returnMoney()**, necesariamente debe realizarse al finalizar la subasta:
```
    function returnMoney() public payable onlyOwner auctionIsClosed returns (bool) {
        for (uint i = 0 ;i<auctList.length-1;i++){
            uint refundAmount = refundList[i].amount - (refundList[i].amount * 2 / 100);
            require (address(this).balance >= refundAmount, "Fondos insuficientes en el contrato");
            (bool sent,) = payable (refundList[i].biddingAddress).call {value: refundAmount}("");
            require(sent, "No se han podido enviar los fondos");    
        }
        return refundDone = true;
    }
```
Esta función arroja un booleano **refundDone = true;** que condiciona la posibilidad de recolectar los fondos remanentes del contrato a que todas las ofertas ganadoras ya se hayan devuelto, para evitar una mala acción por parte del propietario del contrato:
```
function withdrawContractFunds() public payable onlyOwner auctionIsClosed {
        require(address(this).balance > 0, "No hay fondos para retirar");
        require (refundDone == true, "No se han reembolsado los fondos de las ofertas no ganadoras");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Fallo al retirar fondos");
    }
```
La función avanzada que permite a los oferentes retirar los montos de sus ofertas previas, luego de realizar una nueva crea potenciales riesgos de devolver el dinero en ambas ocasiones, tanto al momento de su reclamo como al finalizar la subasta.
En el contrato hay un mapping que ingresa el último monto ofertado y lo asocia a la clave de la address del oferente:
```
  mapping(address => uint256) public bids;
```
También hay un array de structs destinado a registrar las ofertas que es necesario reembolsar:
```
 AuctionStruct[] public refundList;
```
La función **refundPreviousBids()** compara la dirección del oferente asociada al monto de la última oferta realizada, registradas en el mapping, con los montos asociados al array de structs que contienen el historial de ofertas que ese oferente ha realizado previamente, permitiéndole retirar los fondos de sus ofertas previas. Luego de realizado el reembolso se le asigna un valor 0 al monto de la oferta realizada, lo que impide que se vuelva a reembolsar a futuro.
```
    function refundPreviousBids() public payable {
        for (uint i=0;i<refundList.length;i++) {
            uint refundPreviousBidsAmount = refundList[i].amount - (refundList[i].amount * 2 / 100);
            require (address(this).balance >= refundPreviousBidsAmount, "Fondos insuficientes en el contrato");
            //Si la dirección del oferente aparece en la lista de reembolsos 
            // y no coincide con su oferta actual hacemos la transacción
            if(msg.sender == refundList[i].biddingAddress && bids[msg.sender]!= refundList[i].amount){  
            (bool sent,) = payable (refundList[i].biddingAddress).call {value: refundPreviousBidsAmount}("");
            require(sent, "No se han podido enviar los fondos");
            //Una vez retirados los fondos le asignamos el valor en 0
            //para evitar volver a transferirle los fondos al finalizar la subasta
            refundList[i].amount = 0; 
            }
        }
    }
```
En la versión final se ha removido la implementación de la interfase porque generaba problemas a la hora de verificar el contrato y no era estrictamente necesaria.


