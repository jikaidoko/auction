//SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


contract Auction {

    address public owner;
    uint256 public startTime;
    uint256 public timeLimit;
    uint256 public extratime;
    address public biddingAddress;
    uint256 public amount;
    uint256 public highestBid;
    string public auctionStarted;
    string public extraTime;
    string public auctionFinished;
    bool public startAuction;
    bool public endAuction;
    bool refundDone;

    //Mapping para poder acceder a las ofertas con la address del oferente
    mapping(address => uint256) public bids;

    //Struct para armar el listado de todos los oferentes y ofertas de la subasta
    struct AuctionStruct{
        address biddingAddress;
        uint256 amount;        
    } 

    //Array de Structs para agregar las nuevas ofertas
    AuctionStruct[] public auctList;

    //Array de Structs para devolver el dinero de las ofertas no ganadoras
    AuctionStruct[] public refundList;

    //Evento para notificar la apertura de la subasta
    event StartAuction(string auctionStarted);

    //Evento para notificar cuando se hace una oferta superadora
    event Bid(address bidder, uint256 amount);

    //Evento para notificar que se ha añadido tiempo extra
    event ExtraTime(string extraTime);
    //Evento para notificar que la subasta ha finalizado
    event EndAuction(string auctionFinished);
    
    /*El constructor inicia la subasta 
    con los parámetros necesarios para su funcionamiento*/
    constructor() {
         owner = msg.sender;
         auctionStarted = "La subasta ha iniciado";
         extraTime = "Se ha agregado tiempo extra a la subasta";
         auctionFinished = "La subasta ha finalizado";
    }

   
    /*No puede volver a pujar el mayor oferente*/
    modifier notTopBidder () {
        if (auctList.length > 0) { 
        require(msg.sender != auctList[auctList.length-1].biddingAddress, "Ya eres el mayor oferente");
        }
        _;
    }

    //Modificador para acciones que solo puedan ejecutarse cuando está abierta la subasta
    modifier auctionIsOpen () {
        require(block.timestamp<timeLimit+extratime, "El tiempo de la subasta ha expirado");
        _;
    }

    //Modificador para acciones que solo puedan ejecutarse cuando está cerrada la subasta
    modifier auctionIsClosed () {
        require(endAuction == true,"La subasta no ha terminado");
        _;
    }

    //Acciones que solo puede ejecutar el owner del contrato
    modifier onlyOwner () {
        require(msg.sender == owner,"Necesitas ser el propietario del contrato"); 
        _;
    }
    //Acciones que no puede ejecutar el owner del contrato
    modifier notOwner (){
        require (msg.sender != owner,"El propietario del contrato no puede ofertar");
        _;
    }

    //Función para iniciar la subasta
    function openAuction(uint256 _timeLimit, uint256 _extratime) public onlyOwner returns (bool _endAuction) {
        require(startAuction == false, "La subasta ya ha iniciado");
        startTime = block.timestamp;
        timeLimit= startTime + _timeLimit;
        extratime = _extratime;
        //emitimos un alerta para informar la apertura de la subasta
        emit StartAuction(string (auctionStarted));
        
        return startAuction = true;
    }

    //Función para ofertar
    function newBid() public payable notOwner auctionIsOpen notTopBidder {
        /*La oferta válida debe ser al menos un 5% mayor que la oferta anterior*/
        require(msg.value!= 0 && msg.value > highestBid + highestBid*5/100,
        "La nueva oferta debe superar al menos un 5 por ciento a la oferta anterior");

        //Guardamos el nuevo mayor oferente en la variable de la subasta
        highestBid = msg.value;

        //emitimos un alerta de que se ha recibido una nueva oferta
        emit Bid(msg.sender, highestBid);

        /*Guardamos la oferta en el mapping 
        para asignarla como nuevo mayor oferente de la subasta*/           
        bids[msg.sender] = highestBid;
        
        //Guardamos la nueva oferta en el listado del historial de ofertas
        auctList.push (AuctionStruct({biddingAddress: msg.sender, amount: highestBid}));

        //Guardamos la nueva oferta en el listado de ofertas potencialmente reembolsables
        refundList.push (auctList[auctList.length-1]);

        /*Asignamos tiempo extra a la subasta si la última oferta 
        se realiza en los 10 minutos finales*/
        uint256 newTimeLimit; //Nuevo tiempo límite de la subasta

        if (timeLimit - block.timestamp < 10 minutes){
            newTimeLimit = timeLimit + extratime;
            //Ajustamos el tiempo límite de la subasta sumando el tiempo extra
            timeLimit = newTimeLimit;
            //emitimos un alerta para informar que se ha añadido tiempo extra a la subasta
            emit ExtraTime (string (extraTime)); 
        }
    }

    //Función para cerrar la subasta
    function closeAuction() public onlyOwner returns (bool _endAuction) {
    if (block.timestamp>=timeLimit+extratime){
                return endAuction=true;
    }
    emit EndAuction(string (auctionFinished));
    }

    //Publicamos la address y la oferta del ganador de la subasta
    function publishWinner() public view returns (address , uint256){
        return (auctList[auctList.length-1].biddingAddress, 
        auctList[auctList.length-1].amount);
    }

    //Publicamos todas las apuestas y sus address recibidas a lo largo de la subasta
    function publishBids() public view returns (AuctionStruct[] memory) {
        return auctList;
    }

    //Publicamos la lista de las ofertas a reembolsar (recordar excluir la última)
    function publishRefundBids() public view returns (AuctionStruct[] memory) {
        return refundList;
    }

    //Función para que los oferentes de la subasta reclamen el reembolso de las ofertas previas
    function refundPreviousBids() public payable {
        for (uint i=0;i<refundList.length;i++) {
            uint refundPreviousBidsAmount = refundList[i].amount - (refundList[i].amount * 2 / 100);
            require (address(this).balance >= refundPreviousBidsAmount, "Fondos insuficientes en el contrato");
            //Si la dirección del oferente aparece en la lista de reembolsos 
            // y no coincide con su oferta actual (guardada en el mapping) hacemos la transacción
            if(msg.sender == refundList[i].biddingAddress && bids[msg.sender]!= refundList[i].amount){  
            (bool sent,) = payable (refundList[i].biddingAddress).call {value: refundPreviousBidsAmount}("");
            require(sent, "No se han podido enviar los fondos");
            //Una vez retirados los fondos de la lista de reembolsos le asignamos el valor en 0
            //para evitar volver a transferirle los fondos al finalizar la subasta
            refundList[i].amount = 0; 
            }
        }
    }

    //Mandamos la cantidad de fondos a las oferentes no ganadores
    //Retiramos la oferta ganadora del Array iterando hasta el penúltimo lugar
    function returnMoney() public payable onlyOwner auctionIsClosed returns (bool) {              
        for (uint i = 0 ;i<auctList.length-1;i++){
            uint refundAmount = refundList[i].amount - (refundList[i].amount * 2 / 100);
            require (address(this).balance >= refundAmount, "Fondos insuficientes en el contrato");
            
            //Lo hacemos con un call de la librería "payable" y retenemos el 2% del monto ofertado
            (bool sent,) = payable (refundList[i].biddingAddress).call {value: refundAmount}("");
            require(sent, "No se han podido enviar los fondos");    
        }
        return refundDone = true;      
    }  

    // Función para que el propietario pueda retirar fondos del contrato al terminar la subasta
    function withdrawContractFunds() public payable onlyOwner auctionIsClosed {
        require(address(this).balance > 0, "No hay fondos para retirar");
        require (refundDone == true, "No se han reembolsado los fondos de las ofertas no ganadoras");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Fallo al retirar fondos");
    }
}