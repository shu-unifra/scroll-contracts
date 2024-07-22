// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {IL1ETHGateway} from "../L1/gateways/IL1ETHGateway.sol";
import {IL1ScrollMessenger} from "../L1/IL1ScrollMessenger.sol";
import {IL2ETHGateway} from "../L2/gateways/IL2ETHGateway.sol";

import {IMessageDropCallback} from "../libraries/callbacks/IMessageDropCallback.sol";
import {ScrollGatewayBase} from "../libraries/gateway/ScrollGatewayBase.sol";

// solhint-disable avoid-low-level-calls

/// @title L1GasTokenGateway
/// @notice The `L1GasTokenGateway` is used to deposit gas token on layer 1 and
/// finalize withdraw gas token from layer 2.
/// @dev The deposited gas tokens are held in `L1ScrollMessenger`. On finalizing withdraw, the corresponding
/// gas token will be transfer to the recipient directly.
contract L1GasTokenGateway is ScrollGatewayBase, IL1ETHGateway, IMessageDropCallback {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /*************
     * Constants *
     *************/

    address public immutable gasToken;

    /***************
     * Constructor *
     ***************/

    /// @notice Constructor for `L1GasTokenGateway` implementation contract.
    ///
    /// @param _gasToken The address of gas token in L1.
    /// @param _counterpart The address of `L2ETHGateway` contract in L2.
    /// @param _router The address of `L1GatewayRouter` contract in L1.
    /// @param _messenger The address of `L1ScrollMessenger` contract in L1.
    constructor(
        address _gasToken,
        address _counterpart,
        address _router,
        address _messenger
    ) ScrollGatewayBase(_counterpart, _router, _messenger) {
        if (_gasToken == address(0) || _router == address(0)) revert ErrorZeroAddress();

        _disableInitializers();

        gasToken = _gasToken;
    }

    /// @notice Initialize the storage of L1GasTokenGateway.
    function initialize() external initializer {
        ScrollGatewayBase._initialize(address(0), address(0), address(0));
    }

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @inheritdoc IL1ETHGateway
    function depositETH(uint256 _amount, uint256 _gasLimit) external payable override {
        _deposit(_msgSender(), _amount, new bytes(0), _gasLimit);
    }

    /// @inheritdoc IL1ETHGateway
    function depositETH(
        address _to,
        uint256 _amount,
        uint256 _gasLimit
    ) external payable override {
        _deposit(_to, _amount, new bytes(0), _gasLimit);
    }

    /// @inheritdoc IL1ETHGateway
    function depositETHAndCall(
        address _to,
        uint256 _amount,
        bytes calldata _data,
        uint256 _gasLimit
    ) external payable override {
        _deposit(_to, _amount, _data, _gasLimit);
    }

    /// @inheritdoc IL1ETHGateway
    function finalizeWithdrawETH(
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) external payable override onlyCallByCounterpart nonReentrant {
        require(msg.value == 0, "msg.value mismatch");

        IERC20Upgradeable(gasToken).safeTransfer(_to, _amount);
        _doCallback(_to, _data);

        emit FinalizeWithdrawETH(_from, _to, _amount, _data);
    }

    /// @inheritdoc IMessageDropCallback
    function onDropMessage(bytes calldata _message) external payable virtual onlyInDropContext nonReentrant {
        // _message should start with 0x232e8748  =>  finalizeDepositETH(address,address,uint256,bytes)
        require(bytes4(_message[0:4]) == IL2ETHGateway.finalizeDepositETH.selector, "invalid selector");

        // decode (receiver, amount)
        (address _receiver, , uint256 _amount, ) = abi.decode(_message[4:], (address, address, uint256, bytes));

        IERC20Upgradeable(gasToken).safeTransfer(_receiver, _amount);

        emit RefundETH(_receiver, _amount);
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev The internal ETH deposit implementation.
    /// @param _to The address of recipient's account on L2.
    /// @param _amount The amount of ETH to be deposited.
    /// @param _data Optional data to forward to recipient's account.
    /// @param _gasLimit Gas limit required to complete the deposit on L2.
    function _deposit(
        address _to,
        uint256 _amount,
        bytes memory _data,
        uint256 _gasLimit
    ) internal virtual nonReentrant {
        // 1. Extract real sender if this call is from L1GatewayRouter.
        address _from = _msgSender();

        if (router == _from) {
            (_from, _data) = abi.decode(_data, (address, bytes));
        }

        // 2. transfer gas token from caller
        uint256 _before = IERC20Upgradeable(gasToken).balanceOf(address(this));
        IERC20Upgradeable(gasToken).safeTransferFrom(_from, address(this), _amount);
        uint256 _after = IERC20Upgradeable(gasToken).balanceOf(address(this));
        _amount = _after - _before;
        require(_amount > 0, "deposit zero gas token");

        // 3. Generate message passed to L1ScrollMessenger.
        bytes memory _message = abi.encodeCall(IL2ETHGateway.finalizeDepositETH, (_from, _to, _amount, _data));

        IL1ScrollMessenger(messenger).sendMessage{value: msg.value}(counterpart, _amount, _message, _gasLimit, _from);

        emit DepositETH(_from, _to, _amount, _data);
    }
}