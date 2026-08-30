# type: ignore

import os
import sys
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

import torch
from transformers import GenerationConfig, pipeline
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn


if len(sys.argv) > 1:
    PathToModel = sys.argv[1]
else:
    PathToModel = "Qwen/Qwen3.5-0.8B"

text_generation_pipeline = pipeline(
    task="text-generation",
    model=PathToModel,
    tokenizer=PathToModel,
    dtype="auto",
    device_map={"": "cpu"},
)

text_generation_pipeline.generation_config = GenerationConfig(
    max_length=None,
    max_new_tokens=256,
    do_sample=True,
    temperature=0.7,
    pad_token_id=text_generation_pipeline.tokenizer.eos_token_id,
    eos_token_id=text_generation_pipeline.tokenizer.eos_token_id,
)

class QuestionRequest(BaseModel):
    grade: str
    subject: str
    unit: str
    type: str
    scope: str


class GradeRequest(BaseModel):
    ques: str
    userAns: str


def extract_chat_output(response):
    if isinstance(response, list) and response and isinstance(response[0], dict):
        generated = response[0].get("generated_text", "")
        if isinstance(generated, list):
            if generated and isinstance(generated[-1], dict):
                return generated[-1].get("content", "")
            return str(generated[-1]) if generated else ""
        if isinstance(generated, str):
            return generated
    if isinstance(response, dict):
        generated = response.get("generated_text", "")
        if isinstance(generated, list):
            if generated and isinstance(generated[-1], dict):
                return generated[-1].get("content", "")
            return str(generated[-1]) if generated else ""
        if isinstance(generated, str):
            return generated
    if isinstance(response, str):
        return response
    return str(response)


service = FastAPI()

@service.post("/ques")
def quesService(unit: QuestionRequest):
    print(f"[server] received /ques: {unit.grade} | {unit.subject} | {unit.unit} | {unit.type}", flush=True)
    messages = [
        {"role": "system", "content": "你是一个出卷老师，请按照科目、单元、年级、题型、范围出题。choose代表选择/判断, fillBlank代表填空, answer代表实验探究/解答/综合。数学、科学使用浙教版，英语使用外研版，剩余科目使用人教版。只需出一题即可。不需要给出答案。",},
        {"role": "user", "content": f"科目:{unit.subject}，年级:{unit.grade[1]+unit.grade[0]}，单元:{unit.unit}，题型:{unit.type}，范围:{unit.scope}"},
    ]
    response = text_generation_pipeline(
        messages,
        return_full_text=False,
    )
    output = extract_chat_output(response)
    print("[server] /ques generation finished", flush=True)
    return {"text": output}

@service.post("/grade")
def gradeService(ques: GradeRequest):
    print(f"[server] received /grade: ques={ques.ques[:60]} ... userAns={ques.userAns[:60]}", flush=True)
    messages = [
        {"role": "system", "content": "你是一个批改作业的老师。请根据题目类型进行评分：选择题和填空题每空1分，若回答正确则输出 1/1；若回答错误则输出 0/1；若题目包含多个空，请按空数给出如 2/3 或 1/3 的分数。请只输出最终评分结果，不要解释。",},
        {"role": "user", "content": f"题目:{ques.ques}，学生答案:{ques.userAns}"},
    ]
    response = text_generation_pipeline(
        messages,
        return_full_text=False,
    )
    output = extract_chat_output(response)
    print("[server] /grade generation finished", flush=True)
    return {"text": output}

@service.get("/test")
def testService():
    print("[server] received /test", flush=True)
    return {"text": True}

if __name__ == "__main__":
    uvicorn.run(service, host="127.0.0.1", port=8000)