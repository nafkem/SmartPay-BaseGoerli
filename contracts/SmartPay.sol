// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SmartPay {
    error invalidAddress();
    error insufficentAmount();
    error userNotVerified();
    error insufficentInterestRate(
        uint256 _interestRate
    );
    error invalidLoan(
        address _address,
        uint256 _loanId
    );

    error loanIsNotDisbursed();
    
     enum LoanStatus {
        Pending,
        Approved,
        Disbursed,
        Repaid,
        Rejected
    }
        
     struct Loan {
        address lender;
        address borrower;
        uint256 amount;
        uint256 amountFunded;
        uint256 interestRate;
        LoanStatus status;
        uint256 loanId;
    }

    //State Variables
    address private immutable i_owner;
    address[] public s_lenders;
    address[] public s_borrowers;

    uint256 public constant MINIMUM_INTEREST = 3;
    uint256 private s_lenderCount;
    uint256 private s_borrowerCount;
    uint256 private s_loanCount;
    uint256 private s_approvedLoanCount;

    mapping(address => bool) s_isLender;
    mapping(address => bool) s_isBorrower;
    mapping(address => bool) public s_isVerified;
    mapping(uint256 => bool) public s_isApproved;
    mapping(address => mapping(uint => Loan)) public s_loans;
    mapping(address => mapping(uint => Loan)) public s_approvedLoans;

     //Events 
    event LoanApproved(
        address indexed lender,
        address indexed borrower
    );
    event LoanDisbursed(
        address indexed lender,
        address indexed borrower,
        uint256 indexed amount
    );
    event LoanRepaid(
        address indexed lender,
        address indexed borrower,
        uint256 indexed amount
    );

    event LoanRequested(
        address indexed borrower,
        uint256 indexed amount,
        uint256 indexed interestRate
    );

    event LenderRegistered(
        address indexed lender
    );

     event borrowerRegistered(
        address indexed borrower
    );

        //
      modifier onlyAdmin() {
        require(msg.sender == i_owner, "Not authorized");
        _;
    }

    modifier onlyLender() {
        require(s_isLender[msg.sender], "Not authorized");
        require(s_isVerified[msg.sender], "Lender not verified");
        _;
    }

    modifier onlyBorrower() {
        require(s_isBorrower[msg.sender], "Not authorized");
        require(s_isVerified[msg.sender], "Borrower not verified");
        _;
    }

    modifier notVerified() {
        require(!s_isVerified[msg.sender], "User is already verified");
        _;
    }

    modifier blankCompliance(address _address, uint256 _loanId) {
        if(_address == address(0) && !s_isVerified[_address]) {
            revert invalidAddress();
        }

        if(_loanId > s_loanCount && s_loans[_address][_loanId].status != LoanStatus.Pending) {
            revert invalidLoan(
                _address,
                _loanId
            );
        }
        _;  
    }

    constructor() {
        i_owner = msg.sender;
         s_lenderCount = 0;
        s_borrowerCount = 0;
        s_loanCount = 0;
        s_approvedLoanCount = 0;
    }

    receive() external payable {
    }

    function registerAsLender() external notVerified {
        s_lenderCount++;

        s_isLender[msg.sender] = true;
        s_lenders.push(msg.sender);

        emit LenderRegistered(msg.sender);
    }

    function registerAsBorrower() external notVerified {
        s_borrowerCount++;
        s_isBorrower[msg.sender] = true;
        s_borrowers.push(msg.sender);

    }

    function verifyUser(address _user) external onlyAdmin notVerified  {
        s_isVerified[_user] = true;
    }
function requestLoan(uint256 _amount, uint256 _interestRate) external onlyBorrower  {
        if(_amount <= 0) {
            revert insufficentAmount();
        }
        
        if(!s_isVerified[msg.sender]) {
            revert userNotVerified();
        }

        if(_interestRate < MINIMUM_INTEREST) {
            revert insufficentInterestRate(
                _interestRate
            );
        }

         s_loanCount++;
         

         uint256 loanId = s_loanCount;
         


         s_loans[msg.sender][loanId] = Loan({
            lender: address(0),
            borrower: msg.sender,
            amount: _amount + 0 ether,
            amountFunded: 0 ether,
            interestRate: _interestRate,
            status: LoanStatus.Pending,
            loanId: loanId

         });

         emit LoanRequested(msg.sender, _amount, _interestRate);


        
    }

    function approveLoan(address _address, uint256 _loanId) external onlyAdmin {
        if(_address == address(0) && !s_isVerified[_address]) {
            revert invalidAddress();
        }

        if(_loanId > s_loanCount && s_loans[_address][_loanId].status != LoanStatus.Pending) {
            revert invalidLoan(
                _address,
                _loanId
            );
        }

        s_approvedLoanCount++;
        s_isApproved[_loanId] = true;
        address borrower = s_loans[_address][_loanId].borrower;

         s_loans[_address][_loanId].status = LoanStatus.Approved;
        s_approvedLoans[_address][_loanId].status = LoanStatus.Approved;

        emit LoanApproved(address(0), borrower );
    }


    function fundLoan(address _address, uint256 _loanId) external payable onlyLender blankCompliance(_address, _loanId)  {
        Loan storage loan = s_loans[_address][_loanId];

        if(loan.status != LoanStatus.Approved) {
            revert("loan is not approved");
        }
        if(msg.value < loan.amount) {
            revert("insufficent amount");
        }

        loan.amountFunded += msg.value;
        loan.lender = msg.sender;
        loan.status = LoanStatus.Disbursed;

        (bool sent, ) = payable(loan.borrower).call{value: msg.value}("");
        if(!sent) {
            revert("This transaction failed");
        }

        emit LoanDisbursed(msg.sender, loan.borrower, msg.value);



    }

    function repayLoan(address _address, uint256 _loanId) external payable onlyBorrower blankCompliance(_address, _loanId) {
        Loan storage loan = s_loans[_address][_loanId];

        if(loan.status != LoanStatus.Disbursed) {
            revert loanIsNotDisbursed();
        }

        uint256 amountToReturn = loan.amountFunded;
        uint256 percentageToAdd = (amountToReturn * loan.interestRate) / 100;
        amountToReturn = percentageToAdd;

        if(msg.value < amountToReturn) {
            revert("Insufficent amount ");
        }

        loan.status = LoanStatus.Repaid;

        (bool sent, ) = payable(loan.lender).call{value: amountToReturn}("");
        if(!sent) {
            revert("This transaction failed");
        }

         emit LoanRepaid(loan.lender, loan.borrower, loan.amount);
    }


    function getLoanCount() external view returns(uint256 loanCount) {
        return s_loanCount;    
        }
        function getAllLoans() external view returns (Loan[] memory) {
        Loan[] memory allLoans = new Loan[](s_loanCount);
        for (uint256 i = 0; i < s_loanCount; i++) {
            Loan memory loan = s_loans[s_borrowers[i]][i];
            allLoans[i] = loan;
        }

        return allLoans;
    }

    function getLoan(
        address _address,
        uint256 _loanId
    )
        external
        view
        returns (
            address _borrower,
            address _lender,
            uint256 _amount,
            uint256 _amountFunded,
            uint256 _interestRate,
            LoanStatus _status,
            uint256 _Id
        )
    {
        Loan memory loan = s_loans[_address][_loanId];

        return (
            loan.borrower,
            loan.lender,
            loan.amount,
            loan.amountFunded,
            loan.interestRate,
            loan.status,
            loan.loanId
        );
    }

    function getApprovedLoans() external view returns (Loan[] memory) {
        Loan[] memory allApprovedLoans = new Loan[](s_approvedLoanCount);

        for (uint256 i = 0; i < s_approvedLoanCount; i++) {
            Loan memory loan = s_approvedLoans[s_borrowers[i]][i];

            if (loan.status == LoanStatus.Approved) {
                allApprovedLoans[i] = loan;
            }
        }

        return allApprovedLoans;
    }
    
}