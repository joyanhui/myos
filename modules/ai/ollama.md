```bash
GPU: AMD Radeon 680M [Integrated] GFX1035

ollama run deepseek-r1:1.5b #6-8 GB.
ollama run deepseek-r1:7b-qwen-distill-q4_K_M  # 4.7 GB
ollama run deepseek-r1:8b-llama-distill-q4_K_M  # 4.9 GB

ollama run gemma3:1b-it-q4_K_M # 815M
ollama run gemma3:1b-it-q8_0   # 1.1G
ollama run gemma3:1b-it-fp16  # 2G 好像很啰嗦 SIZE4.9G

ollama run gemma3:4b-it-q4_K_M    # 8.6G
ollama run gemma3:4b-it-q8_0     #5G
ollama run gemma3:4b-it-fp16      #8.6G

ollama run phi4-mini:3.8b-q4_K_M # 2.5GB SIZE 3.4GB  好像很烂
ollama run phi4-mini:3.8b-q8_0  # 4.1GB  SIZE 19GB
ollama run phi4-mini:3.8b-fp16  # 7.7GB

ollama run phi4:14b-q4_K_M    #9.1GB

OpenWebUI  AnythingLLM  LM-Studio Dify FastGPT
Dify 需要本地跑一堆容器\

知识库还可以的就是 ragflow fastgpt ，dify都不太行

docker run -d -p 3001:8080 -v open-webui:/app/backend/data --name open-webui ghcr.io/open-webui/open-webui:main


CodeGemma 有2b和7b
```
Phi-3 Mini	约38亿	4-8 GB	逻辑推理能力强，硬件需求极低，是低配设备的救星。
Qwen 2.5 Coder	14亿	12-16 GB	支持多语言，代码补全能力强，对中文生成尤其友好。
StarCoder2	约30亿	8-24 GB	脚本编写能力强，社区支持广泛，非常灵活。
GLM-Z1-9B	90亿	约9 GB (以Q4量化估算)	专为推理和代码任务优化，在数学和逻辑问题上表现突出。
