//*********************************************************
//
// Copyright (c) Microsoft. All rights reserved.
// This code is licensed under the MIT License (MIT).
// THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
// IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
// PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
//
//*********************************************************

#pragma once

#include <dxcapi.h>
#include <vector>

#include "DXSample.h"
#include "nv_helpers_dx12/TopLevelASGenerator.h"
#include "nv_helpers_dx12/ShaderBindingTableGenerator.h"
#include "VertexTypes.h"
#include "DirectXTex.h"

#include <memory>


using namespace DirectX;

// Note that while ComPtr is used to manage the lifetime of resources on the CPU,
// it has no understanding of the lifetime of resources on the GPU. Apps must account
// for the GPU lifetime of resources to avoid destroying objects that may still be
// referenced by the GPU.
// An example of this can be found in the class method: OnDestroy().
using Microsoft::WRL::ComPtr;

class D3D12HelloTriangle : public DXSample
{
public:
	D3D12HelloTriangle(UINT width, UINT height, std::wstring name);

	virtual void OnInit();
	virtual void OnUpdate();
	virtual void OnRender();
	virtual void OnDestroy();

private:
	static const UINT FrameCount = 2;

	// Pipeline objects.
	CD3DX12_VIEWPORT m_viewport;
	CD3DX12_RECT m_scissorRect;
	ComPtr<IDXGISwapChain3> m_swapChain;
	ComPtr<ID3D12Device5> m_device;
	ComPtr<ID3D12Resource> m_renderTargets[FrameCount];
	ComPtr<ID3D12CommandAllocator> m_commandAllocator;
	ComPtr<ID3D12CommandQueue> m_commandQueue;
	ComPtr<ID3D12RootSignature> m_rootSignature;
	ComPtr<ID3D12DescriptorHeap> m_rtvHeap;
	ComPtr<ID3D12PipelineState> m_pipelineState;
	ComPtr<ID3D12GraphicsCommandList4> m_commandList;
	UINT m_rtvDescriptorSize;

	// App resources.
	ComPtr<ID3D12Resource> m_tetrahedronVertexBuffer;
	D3D12_VERTEX_BUFFER_VIEW m_tetrahedronVertexBufferView;

	// Synchronization objects.
	UINT m_frameIndex;
	HANDLE m_fenceEvent;
	ComPtr<ID3D12Fence> m_fence;
	UINT64 m_fenceValue;

	bool m_raster = true;
	
	void LoadPipeline();
	void LoadAssets();
	void PopulateCommandList();
	void WaitForPreviousFrame();

	void CheckRaytracingSupport();
	virtual void OnKeyUp(UINT8 key);

	//#DXR
	struct AccelerationStructureBuffers
	{
		ComPtr<ID3D12Resource> pScratch;		// Scratch memory for AS builder
		ComPtr<ID3D12Resource> pResult;			// Where the AS is
		ComPtr<ID3D12Resource> pInstanceDesc;	// Hold the matrices of the instances
	};

	ComPtr<ID3D12Resource> m_bottomLevelAS;

	nv_helpers_dx12::TopLevelASGenerator m_topLevelASGenerator;
	AccelerationStructureBuffers m_topLevelASBuffers;
	std::vector<std::pair<ComPtr<ID3D12Resource>, DirectX::XMMATRIX>> m_instances;

	/// <summary>
	/// Create the acceleration structure of an instance
	/// </summary>
	/// <param name="vVertexBuffers">pair of buffer and vertex count</param>
	/// <returns>AccelerationStructureBuffers for TLAS</returns>
	AccelerationStructureBuffers CreateBottomLevelAS(
		std::vector<std::pair<ComPtr<ID3D12Resource>, uint32_t>> vVertexBuffers,
		std::vector<std::pair<ComPtr<ID3D12Resource>, uint32_t>> vIndexBuffers = {});


	// #DXR Extra: Refitting
	/// <summary>
	/// Create the main acceleration structure that holds all instances of the scene
	/// </summary>
	/// <param name="instances"> - pair of BLAS and transform</param>
	/// <param name="updateOnly"> - if true, perform a refit instead of a full build</param>
	void CreateTopLevelAS(const std::vector<std::pair<ComPtr<ID3D12Resource>, DirectX::XMMATRIX>>& instances, bool updateOnly = false);

	void CreateAccelerationStructures();

	// -----------------------------------

	ComPtr<ID3D12RootSignature> CreateRayGenSignature();
	ComPtr<ID3D12RootSignature> CreateMissSignature();
	ComPtr<ID3D12RootSignature> CreateHitSignature();

	void CreateRaytracingPipeline();

	ComPtr<IDxcBlob> m_rayGenLibrary;
	ComPtr<IDxcBlob> m_hitLibrary;
	ComPtr<IDxcBlob> m_missLibrary;

	ComPtr<ID3D12RootSignature> m_rayGenSignature;
	ComPtr<ID3D12RootSignature> m_hitSignature;
	ComPtr<ID3D12RootSignature> m_missSignature;

	// Ray tracing pipeline state
	ComPtr<ID3D12StateObject> m_rtStateObject;
	// Ray tracing pipeline state properties, retaining the shader identifiers
	// to use in the Shader Binding Table
	ComPtr<ID3D12StateObjectProperties> m_rtStateObjectProps;


	// #DXR
	void CreateRaytracingOutputBuffer();
	void CreateShaderResourceHeap();
	ComPtr<ID3D12Resource> m_outputResource;
	ComPtr<ID3D12DescriptorHeap> m_srvUavHeap;

	// #DXR
	void CreateShaderBindingTable();
	nv_helpers_dx12::ShaderBindingTableGenerator m_sbtHelper;
	ComPtr<ID3D12Resource> m_sbtStorage;

	// #DXR Extra: Perspective Camera
	void CreateCameraBuffer();
	void UpdateCameraBuffer();
	ComPtr<ID3D12Resource> m_cameraBuffer;
	ComPtr<ID3D12DescriptorHeap> m_constHeap;
	uint32_t m_cameraBufferSize = 0;

	// #DXR Extra: Perspective Camera++
	void OnButtonDown(UINT32 lParam);
	void OnMouseMove(UINT8 wParam, UINT32 lParam);

	// #DXR Extra: Per-Instance Data
	ComPtr<ID3D12Resource> m_planeVertexBuffer;
	D3D12_VERTEX_BUFFER_VIEW m_planeVertexBufferView;

	void D3D12HelloTriangle::CreateGlobalConstantBuffer();
	ComPtr<ID3D12Resource> m_globalConstantBuffer;

	// #DXR Extra: Per-Instance Data
	void CreatePerInstanceConstantBuffers();
	std::vector<ComPtr<ID3D12Resource>> m_perInstanceConstantBuffers;

	// #DXR Extra: Depth Buffering
	void CreateDepthBuffer();
	ComPtr<ID3D12DescriptorHeap> m_dsvHeap;
	ComPtr<ID3D12Resource> m_depthStencil;

	// #DXR Extra: Indexed Geometry
	ComPtr<ID3D12Resource> m_tetrahedronIndexBuffer;
	D3D12_INDEX_BUFFER_VIEW m_tetrahedronIndexBufferView;

	// #DXR Extra: Another ray type
	ComPtr<IDxcBlob> m_shadowLibrary;
	ComPtr<ID3D12RootSignature> m_shadowSignature;

	// #DXR Extra: Refitting
	uint32_t m_time = 0;

	// #DXR Extra: Refitting (Rasterization)
	/// Per-instance properties
	struct InstanceProperties
	{
		XMMATRIX objectToWorld;
	};

	ComPtr<ID3D12Resource> m_instanceProperties;
	void CreateInstancePropertiesBuffer();
	void UpdateInstancePropertiesBuffer();

	// This value must be manually changed according to implemented setup in CreateShaderBindingTable()
	int m_hitGroupsPerObject = 3;

	// #DXR Custom: Reflections
	ComPtr<IDxcBlob> m_reflectionHitLibrary;
	ComPtr<IDxcBlob> m_reflectionMissLibrary;
	ComPtr<ID3D12RootSignature> m_reflectionSignature;

	// #DXR Custom: Indexed Plane
	ComPtr<ID3D12Resource> m_planeIndexBuffer;
	D3D12_INDEX_BUFFER_VIEW m_planeIndexBufferView;


	// #DXR Custom: Slight Code Refactor
	void CreateMeshBuffers(
		std::vector<Vertex>& vertices, ComPtr<ID3D12Resource>& vertexBuffer, D3D12_VERTEX_BUFFER_VIEW& vertexBufferView,
		std::vector<UINT>& indices, ComPtr<ID3D12Resource>& indexBuffer, D3D12_INDEX_BUFFER_VIEW& indexBufferView);


	// #DXR Custom: Upload textures
	//std::unique_ptr<ScratchImage> m_skyboxTexture = std::make_unique<ScratchImage>();
	ComPtr<ID3D12Resource> m_skyboxTextureBuffer;

	void CreateSkyboxTextureBuffer();

	ComPtr<ID3D12DescriptorHeap> m_samplerHeap;
};
