#version 460

layout(binding = 0, row_major) uniform UniformBufferObject {
    mat4 model;
    mat4 view;
    mat4 proj;
} ubo;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inColor;

layout(location = 0) out vec3 fragColor;

void main() {
    vec4 pos=ubo.proj * ubo.view * ubo.model * vec4(inPosition, 1.0);
    gl_Position = vec4(pos.xy,0,1);
    fragColor = inColor;
}
