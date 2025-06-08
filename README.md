
------------

# TRABAJO PRÁCTICO
## *Fundamentos de Solidity*
### ETH KipuMódulo 2

#### *Instrucciones de uso*
##### - 📦 Constructor:
##### La subasta se inicia al desplegar el contrato
##### - 🏷️ Función para ofertar
##### La función *newBid()* permite realizar la puja 
##### La nueva oferta es válida si:
- Es mayor en al menos 5% que la mayor oferta actual.
- Se realiza mientras la subasta está activa.
- No debe realizarla el propietario del contrato
- No puede volver a ofertar el mayor oferente (debe esperar a que su oferta sea superada por otro)

#####  - 🥇 Mostrar ganador
#####  - La función *publishWinner()* devuelve el oferente ganador y el valor de la oferta ganadora.
##### - 📜 Mostrar ofertas
##### - La función *publishBids()* devuelve la lista de oferentes y sus respectivos montos ofrecidos.
##### - 💸 Devolver depósitos
##### - La función *returnMoney()* devuelve el depósito a los oferentes no ganadores al finalizar la subasta (Se descuenta una comisión del 2%).

------------




#### Detalles del código de la rama del repositorio:
#### *Subasta básica*
La versión inicial del contrato procura cumplir con las todas funciones básicas requeridas en el trabajo práctico.
No posee una función específica para iniciar la subasta, porque esta se inicia al desplegar el contrato, estableciendo el tiempo de inicio directamente en el constructor:
```
constructor() {
         owner = msg.sender;
         startTime = block.timestamp;
         timeLimit = startTime + 120 minutes;
         extratime= 10 minutes;
         endAuction = false;
         highestBid= 1;
         amount=1;
    }
```
La versión avanzada propone en cambio una función específica para iniciar la subasta, de manera que el tiempo de la misma no haya expirado al momento de evaluar el funcionamiento del Smart Contract. 
La función de iniciar la subasta debería estar restringida idealmente al propietario del contrato, pero esto supondría una limitación al momento de interactuar con el mismo.

La función **newBid()** es el método principal para poder realizar las nuevas ofertas de la subasta:
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
La nueva oferta **emite un alerta** tal como solicitaba la consigna:
```
emit Bid(msg.sender, highestBid);
```
También hay una condición, solicitada por la consigna, para **añadir un tiempo extra** si se realiza una oferta en los últimos diez minutos:
```
        if (timeLimit - block.timestamp < 10 minutes){
            newTimeLimit = timeLimit + extraTime;
            timeLimit = newTimeLimit;
        }
```
Hay una función para cerrar la subasta. El sentido que tiene es obligar al propietario del contrato a ejecutarla para habilitar las funciones que requieren que la subasta haya terminado.

El modificador **auctionIsClosed()** habilita las funciones reservadas para el final de la subasta. En esta versión del contrato no fue aplicada a la función de publicar la lista de las ofertas:
```
        function publishBids() public view returns (AuctionStruct[] memory) {
            return auctList;
        }
```

Ni a la función de publicar al ganador de la subasta:
```
        function publishWinner() public view returns (address , uint256){
            return (auctList[auctList.length-1].biddingAddress, 
            auctList[auctList.length-1].amount);
        }
```
Esto es sólo para permitir acceder a estos datos durante la duración de la subasta con fines de testear el funcionamiento de la misma.
Sin embargo sí condiciona a la función de devolver el dinero de las ofertas no ganadoras. Necesariamente eso debe realizarse al finalizar la subasta:
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
Esta función arroja un booleano que condiciona la posibilidad de recolectar los fondos remanentes del contrato a que todas las ofertas ganadoras ya se hayan devuelto, para evitar una mala acción por parte del propietario del contrato:
```
function withdrawContractFunds() public payable onlyOwner auctionIsClosed {
        require(address(this).balance > 0, "No hay fondos para retirar");
        require (refundDone == true, "No se han reembolsado los fondos de las ofertas no ganadoras");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Fallo al retirar fondos");
    }
```
En el contrato hay un mapping que ingresa el monto de las ofertas asociado a la clave de la address del oferente y un array destinado a registrar las ofertas que es necesario reembolsar. En esta versión básica del contrato no tienen mucha funcionalidad, pero están pensados la función avanzada de retirar fondos de ofertas anteriores.
La función **returnMoney()** implementa una interfase que también planea utilizarse para las devoluciones parciales.
