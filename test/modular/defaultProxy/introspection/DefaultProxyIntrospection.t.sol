// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// solhint-disable one-contract-per-file
// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";

import { DefaultProxy } from "src/modular/modules/defaultProxy/DefaultProxy.sol";
import { DefaultProxyFactory } from "src/modular/modules/defaultProxy/DefaultProxyFactory.sol";
import { DefaultProxyStorage } from "src/modular/modules/defaultProxy/DefaultProxyStorage.sol";
import { DefaultProxyIntrospection } from "src/modular/modules/defaultProxy/introspection/DefaultProxyIntrospection.sol";

contract DefaultProxyIntrospectionTest is Test {

    DefaultProxy public proxy;

    function setUp() public {
        DefaultProxyFactory factory = new DefaultProxyFactory();
        address defaultImpl = address(new DefaultProxyStorageSetter());
        DefaultProxyIntrospection introspection = new DefaultProxyIntrospection();
        proxy = factory.deploy(0, defaultImpl, address(this));
        proxy.addExtension(introspection, "");
    }

    function test_introspection_defaultImpl(
        address defaultImpl
    ) public {
        DefaultProxyStorageSetter(address(proxy)).setDefaultImpl(defaultImpl);
        assertEq(DefaultProxyIntrospection(address(proxy)).defaultImpl(), defaultImpl);
    }

    function test_introspection_selectorToExtension(bytes4 selector, address extension) public {
        DefaultProxyStorageSetter(address(proxy)).setSelectorToExtension(selector, extension);
        assertEq(DefaultProxyIntrospection(address(proxy)).selectorToExtension(selector), extension);
    }

    function test_introspection_interfaceSupported(bytes4 interfaceId, bool supported) public {
        DefaultProxyStorageSetter(address(proxy)).setInterfaceSupported(interfaceId, supported);
        assertEq(DefaultProxyIntrospection(address(proxy)).interfaceSupported(interfaceId), supported);
    }

    function test_introspection_extensionToData(
        address extension,
        DefaultProxyStorage.ExtensionData memory extensionData
    ) public {
        DefaultProxyStorageSetter(address(proxy)).setExtensionToData(extension, extensionData);
        DefaultProxyStorage.ExtensionData memory data =
            DefaultProxyIntrospection(address(proxy)).extensionToData(extension);
        assertEq(data.selectors.length, extensionData.selectors.length);
        for (uint256 i = 0; i < data.selectors.length; i++) {
            assertEq(data.selectors[i], extensionData.selectors[i]);
        }
        assertEq(data.interfaceIds.length, extensionData.interfaceIds.length);
        for (uint256 i = 0; i < data.interfaceIds.length; i++) {
            assertEq(data.interfaceIds[i], extensionData.interfaceIds[i]);
        }
    }

}

contract DefaultProxyStorageSetter {

    function setDefaultImpl(
        address defaultImpl
    ) public {
        DefaultProxyStorage.storeDefaultImpl(defaultImpl);
    }

    function setSelectorToExtension(bytes4 selector, address extension) public {
        DefaultProxyStorage.load().selectorToExtension[selector] = extension;
    }

    function setInterfaceSupported(bytes4 interfaceId, bool supported) public {
        DefaultProxyStorage.load().interfaceSupported[interfaceId] = supported;
    }

    function setExtensionToData(address extension, DefaultProxyStorage.ExtensionData memory extensionData) public {
        DefaultProxyStorage.load().extensionToData[extension] = extensionData;
    }

}
