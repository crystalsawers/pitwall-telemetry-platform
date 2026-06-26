# The Art of Google Cloud (Part 4): Experimenting the AI Agent Platform and other APIs

*Project Timeframe: 9 May 2026 – 8 August 2026*

*Link to Part 4 post:* [Part 4]()


**Link to previous posts**: 

_- [Part 1](https://loglapandover.co.nz/projects/devops/P9McSw1XKxtBUFpzdg4g)_

_- [Part 2](https://loglapandover.co.nz/projects/devops/rUzNh2L9nTWgyQQjpVf3)_

_- [Part 3](https://loglapandover.co.nz/projects/devops/8RA0vlrnQM9lmk8gUg8t)_

---

## Intro

In Part 4 of the project, the focus shifts away from the main F1-based project, and delves more into experimenting a few Google Cloud features I haven't really had a chance to play with.

This includes the **AI Agent Platform**, **BigQuery**, **Pub/Sub**, **Cloud Functions**, and **Cloud Storage**.

I could've also used Firebase and Firestore here, but I already use Firebase for this very website, so that will be one that I won't explore into too much detail.

The next (and probably final) part will involve the usage of Terraform in the Google Cloud context to create what I've done in the other three parts of this blog series.

---
## My Love/Hate Rant and Acknowledging My Own Hypocrisy on AI

We are living in a world where AI is very prominent in our society and the fact that a lot of people are either fully leaning into AI, or being completely anti-AI. The thing is, I do agree with a lot of the anti-AI people's views on it, even though I'm personally not completely against AI. I don't particularly like the fact that AI is getting shoved into just about everything from social media to just daily computer life, like even a simple Google search gives you an AI overview at the top. I personally have a real problem with the image, voice, music, and video generation of AI, because there is so much AI slop all over social media, and some are getting so accurate that even I can't tell what is even real anymore, and that's pretty scary. There's a lot of old people on Facebook that like to use those AI avatar emojis too. It's completely ruined my past-time of watching cat videos online too. There's a lot of AI-generated music and AI art usage online too, which I think is quite sad, because there's a lot of aspiring artists and musicians that like to express their creativity. I also don't like the fact that people often use AI chatbots as a therapist, or someone that can give some advice to something.

**But I do like using AI sometimes as a tool.** A tool that can enhance your work, not being a replacement that does it for you because you're too lazy to learn it, and I think that's why a lot of people get too reliant on it, I'm guilty of this sometimes too, so that's the main habit I'm trying to unlearn for myself. Unlearning the AI reliance involves looking at other sources like Youtube tutorials, online forums, and solutions from Stack Overflow and Reddit threads that are about 5 years old. I'm trying to think of using AI as more of a last resort rather than the first thing to use when tacking a problem. But it can speed up the process of learning some tools to use during a project, providing you know what you're doing beforehand, because AI does a lot of hallucinations to the point where it ends up going over things that have nothing to do with what you're prompting. It can also be helpful for when you're trying to come up with ideas for a project, or planning a trip, or even just try and gain understanding of what things mean in my own way of learning (although I'm naturally skeptical of this). 

With that being said, AI has a high risk of developing bias depending on how the model is trained, and it constantly makes a lot of mistakes, especially with basic problem solving and coding in my use case, so I am always skeptical about what information it gives you, and don't trust it blindly. The likes of ChatGPT, Gemini, and other chatbots often go in a loop with the same potential solutions that don't work, even when you tell it to. I've found that a lot of the time, it also doesn't use any recent versioning of software, which can be problematic, and it will tell you it's not a good idea to use the latest version when you tell it to as well, and that's not necessarily a good thing for security purposes, because people out there would have found a way to hack into the older versions too. The chatbot responses also generate way too much information for even a simple question, and as a result of this, doesn't give you a straight answer to your prompt. The most dangerous part about AI in my humble opinion, is the misinformation it gives you when you try to correct it, and it backs up the misinformation out of thin air, and not even backing up with any sources sometimes. A lot of this comes from the AI models having "bias", meaning it's a model that has human biases that the original skew original training data. I do quite like the "machine learning" side of AI and using a model to make predictions on things, but it does depend on how you fine-tune the data you feed into.

This is exactly why it's really **not** a good idea to have AI replacing human jobs, even in IT really, because in my experience, it's terrible at the all the basic human problem-solving skills, and AI often misses even the smallest code mistakes that can break anything, and AI can be unreliable at checking errors too. Not to mention using AI can also be dangerous for when handling sensitive data and cybersecurity tasks, as it can really go wrong for any big company handling privacy, like handling other peoples passwords and other information. Hackers can easily exploit AI to launch cyberattacks, steal information, and manipulate data.

Another thing with AI and more specifically its data centers is that they use a lot of water and energy, in which a lot of water is needed to cool down the amount of heat it emits. The data centers are a big contributor as to why RAM, Hard Drives, SSDs, and CPU has gotten so expensive and constantly out of stock, because AI companies are all using them up to maintain the billions of prompts people use everyday on their devices. I personally think, because AI is getting more expensive to run, it might actually end up cheaper to get a human for a job.

One last rant I've got is about something called "vibe coding", which is something I have done often, getting an LLM (Large Language Model)/Chatbot, yet this technique involves many mistakes I had to fix with my own human brain and non-AI resources, and as I stated earlier, it loops a lot of the same solutions that just don't work, and ChatGPT in particular has always done this. I've seen people arguing and I've even seen it on a job application recently, that anyone can "vibe-code". The problem I have with this statement is that people assume that anyone can just "vibe-code" their way into a project. But not everyone can actually debug, understand what's going wrong and fix the actual code itself with vibe-coding. Can the person actually understand the code the AI response gives you, and can the person be able to fix the errors it puts out without AI looping their 5 solutions in their algorithm in which don't actually fix the root of the issue? I've come across this opinion piece [here](https://brandonkindred.medium.com/vibe-coding-isnt-for-everyone-and-that-s-the-point-15dd6dfe8137) on vibe coding too, which I think is a good read, and reflects better points than I did. Brandon's post touches a bit on the fact that LLMs don't actually think. Instead it's' pattern-matching against solutions it's seen before and generating something that looks right. It doesn't think about the reasoning of the solution it gives out, about the security side of things, the architecture side of a project unless you explicitly prompt it to. They just keep predicting the next token until they hit a stop signal or time out.


---
## Phase 9 - Agent Platform

Gemini Enterprise Agent Platform, which was formerly known as Vertex AI up until right before I started this project, is essentially a platform to run AI models, including Gemini (Google's own AI), Claude, Deepseek, Grok, Llama from Meta, but interestingly, no OpenAI model is available to use here. I will be using the Agent Studio throughout this phase.

There are a lot of APIs that need to be enabled before going into this phase, these are the following that need to be enabled:

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780711537296-agent-platform-apis.png?alt=media&token=d61242d8-ab45-4308-8b1a-ab299752f937)

<br>

There are a lot of ways to setup an environment to experiment with AI. As far as the actual models to use, there are some limitations. I [found out](https://docs.cloud.google.com/free/docs/free-cloud-features#product-free-trials) that in the free trial period you **cannot use any partner (aka third-party) models** like Claude, Grok, Deepseek, Llama (Meta-owned), etc. with the credits in the 90-day trial. So unfortunately, I have to stick with the Google-based models like all the Gemini models.



### 9.1. Creating a simple prompt, Build an AI Agent

 At this stage I will only be testing things out visually with the console, no actual coding yet. It comes up with a screen that lets you type a prompt, like your usual chatbots, and you can choose which model to use. For this basic example I used **Gemini 3.5 Flash**.

For the first prompt in the Agent Studio I asked a simple but specific question. **_"How do I create a basic AI agent here in the new Google Cloud Agent Platform? Simplify this for a complete beginner"_**. The response it gave me is what I have saved in a markdown file, linked here. I specified the Gemini Enterprise Agent Platform here because I found out if you don't do that, it will revert to the old Vertex AI system that doesn't exist anymore. 


<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1781654515895-ai-agent-test-1.png?alt=media&token=592822b7-a14e-48fc-9d25-260ca2467651)

<br>

The response gives you a number of steps to actually build one, so I pretty much followed the instructions. The instructions aren't completely easy to follow, I must admit, but I did manage to figure it out. For example, in Step 3 of the response I got, "Click the **Create agent** button. This will open up the **Agent Studio canvas**, which is your visual workspace.", I actually was already in the Agent Studio page, so I went in the left sidebar and just clicked "Agents". I also just went for the model on by default, which is Gemini 3.5 Flash, rather than the recommended ones at the moment, because I would just want to see how it works. 


<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1781654525851-ai-agent-preview-1.png?alt=media&token=e31fcc7f-a08d-4094-bd84-91256d38c1f2)

<br>

I created an agent based on the instructions, a "Friendly Bakery Assistant" with the following instructions, _"You are a friendly customer service agent for 'Sunny Days Bakery.' You answer questions about opening hours (8 AM - 4 PM) and cake pricing. Be extremely polite, short in your answers, and use bakery-themed emojis."_. I then click on the preview tab to ask what time it closes, to which it responds this, "Hello! ☀️ We close at 4 PM. We hope to bake some sweet memories for you soon! 🍰🧁". There is an option to deploy the Agent but unfortunately it's currently only available in the `us-west1` region, and not the `australia-southeast1` region.


### 9.2. Creating an app, with AI App Builder

Now I'm gonna move on the to **App builder** in Agent Studio. Originally I was going to use one of the Claude models for this, because I have heard great things about Claude in general, but I fell into a barrier of which I can only really use Gemini-based models. The model I used here was **Gemini 3.1 Pro Preview**.

Here was my first prompt, which is a very basic coding concept: _"Create a very simple click button with a counter that increments each click."_.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1781817240456-simple-counter-app-1.png?alt=media&token=a89a6248-2d27-40f8-b7be-f0bc44872071)

<br>

This is what the App builder had made in the space of about 20 seconds, which is the Simple Counter. It states which files have been made to create this in the response, and it has three tabs. The "Specs" tab gives you the details on which model and region you can use. In my case the region was on Global by default, and the model was on Gemini 3.1 Pro Preview. The "Code" tab gives you all the code from the files in created, which was in the language of TypeScript and used the React Framework, which is pretty much just a fussier sister language to JavaScript. Of course, the "Preview" part is how people see the coded app.

Now, I am going to use a second prompt, this time it's adjacent to the type of project I've been doing this series: "_Build a basic full-stack application based on a typical F1 Telemetry System in 2026. Include the following data:_

_- Drivers Championship_

_- Constructors Championship_

_- Race Results from the last Grand Prix (e.g. Barcelona-Catalunya Grand Prix)_

_- Details of the Grand Prix like location, number of laps, date, race time in the local timezone._
".

This one took a bit longer to build, it also took about 2 minutes to complete, and the data doesn't match up to the actual one, it's basically mock data.

<br>
<video controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2FF1%20telemetry%20app%20AI%201.mp4?alt=media&token=336988f8-220f-4cc8-bb20-4ba5712172cb" type="video/mp4">
  Your browser does not support the video tag.
</video>
<br>

I did decide to prompt some improvements. For the dashboard I also wanted a way to convert the local time and date to my local time zone and toggle it with the track's local timezone. I also wanted in the main dash on who won the race, and who was on the podium, and the top 3 in drivers championship name to be changed from "Drivers Top 3", to "Drivers Championship". For race results page I want a column on how many laps each driver has completed.

Prompt #2 (Improvement): _"Dashboard needs changes: A feature to toggle Local Track Time and Data to a timezone of choice (e.g. NZST), the race winner of that Grand Prix along with the podium, and the top 3 in drivers chmpaionship name to be changed from "Drivers Top 3", to "Drivers Championship". For race results page I want a column on how many laps each driver has completed."_.

<br>
<video controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2FF1%20telemetry%20app%20AI%202.mp4?alt=media&token=752f3a9a-96fc-4e20-b387-8cbbf40b831d" type="video/mp4">
  Your browser does not support the video tag.
</video>
<br>

The improvement did come up with a slight coding error occuring but it was a minor one that was an easy auto-fix and the changes applied. 


Now for one last prompt for tweaking. You may notice that there is a "System Config" at the bottom of the page. When I click on this, nothing happens, so it's useless. Also, in the live telemetry page there is an example of a driver being tracked. Now I want a feature that helps me be able to pick any driver on the grid and live track.

Prompt #3: _"Remove the "System Config" at the bottom and it does nothing to add to the system. In the Live Telemetry page, add a feature that lets me pick any driver for me to track."_

<br>
<video controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2FF1%20telemetry%20app%20AI%203.mp4?alt=media&token=fff3fe64-e3f1-47f7-922a-f56eaf130865" type="video/mp4">
  Your browser does not support the video tag.
</video>
<br>

As you can see, the Live Telemetry still isn't perfect because it's going off mock data that seems to apply the same to all drivers, so there's no variety on tyres, or things like RPM, throttle, brakes, or speed.

Final Prompt: _"Add some variety for each driver on tyres, RPM, throttle, brakes, and speed, while maintaining the simulated "live" feel."_

<br>
<video controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2FF1%20telemetry%20app%20AI%204.mp4?alt=media&token=46dcc0d0-3049-4f0a-b42c-dcd2752eeea2" type="video/mp4">
  Your browser does not support the video tag.
</video>
<br>

It was successful. I clicked on a few drivers and there was indeed variety, and the most realistic thing about it is that AI has replicated McLaren putting on a terrible tyre strategy on Lando Norris.


### 9.3 - How Easy it is to create AI Slop, with Various Models

As much as I'm not personally a fan or generating images, music, and videos with AI, I'm gonna use this section as an example of how easy it is to make "AI slop" that you would see normally on social media these days. There's even an "AI evolution" video which involves AI's interpretation of "Will Smith eating Spaghetti", basically a yearly benchmark of AI. It's also gotten into legal trouble with using celebrities and people without consent. There's been [some news here in New Zealand](https://www.nzherald.co.nz/lifestyle/huffer-accused-of-using-ai-to-recreate-models-in-new-campaign/3DPGKAUS3JDJLP6SDTWOO7AVIU/) about an advertisement regarding Huffer, a NZ-owned clothing brand, using model's faces without their consent to generate their own models (and I don't mean AI models, I mean fashion models) to model their clothing, which I personally think is so scummy that Huffer, or any company, can get away with it without repercussions.

I'm gonna dabble into the **Generate Media** (aka Generate AI Slop) section. It's out of my moral confort zone (and hypocritical of me to do this), and it's purely for the content of my blog, but the main reason I'm doing this is to show the scary reality of how easy it is to make. I'm not going to steal famous people's faces or anything, as I find that disrespectful, and it violates consent.  

Models being used:

- **Veo 3.1** for Video Generation
- **Chirp 3** for Speech
- **Lyria 3 Pro** for Music
- **Gemini 3.1 Flash Image Preview**

Starting with the images. I'm going to prompt a famous landmark in New Zealand that I've been to, but in the interior perspective.

**Image prompt:** _"Generate an image of the interior view of the Auckland Sky Tower"_.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1781850110296-ai-slop-sky-tower.png?alt=media&token=f1cca674-3516-40c0-aa6e-d68bc9b2b803)

<br>


The result comes up with this photo above. The simulated reflection of the image is disturbingly realistic, as if it's an actual stock photo of the Sky Tower's interior. As someone who has been up the Sky Tower last year, I can already spot the first of many major flaws here. In the right corner of the image, there appears to be another lookout level "hole" below, when that is not the case when you're actually up there, in any level you go up to. Another major flaw is the fact that there isn't any glass floors that directly look down or seating, and there's no card signs either, certainly not one called "Skydeek". There's many more you can spot the closer you look at the photo, but I'll let you, the reader, to spot the difference between this slop and the real view of the Sky Tower you can use Google Images for, there's real stock photos there, and they certainly show you the glass floor, seating, and the binoculars too.


Up next is a **text-to-video** prompt, where I prompt something ridiculous: _"Visualise a psychedelic acid trip, where every colour is a trippy illusion, and the 2D fruits fall from the sky as rain"_.

<br>
<video controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2Fai-slop-text-to-video.mp4?alt=media&token=8884ef60-b6f0-44d0-bff1-22dd61a598aa" type="video/mp4">
  Your browser does not support the video tag.
</video>
<br>

It generates an 8-second video without sound of whatever this is. What I was expecting was what's normally portrayed in the media of what an acid trip looks and feels like. Don't ask me why this idea came into my head, the point of this idea was that I wanted to show that this really is useless slop people are wasting tokens on. There's also options to input images to video as well, but I only really had a go at the examples that Google had. 

**Speech** is another feature of the AI slop genre. There's a few different models you can use here and you can customise the style of speech delivery in some of them. You can also choose the accent/language and gender of the voice. My prompt was just some made-up crap brought to you by my own brain: _"This is going to change everything. The digital sludge that humans create, will become a world full of wasteland."_.

<br>

<audio controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2Fai-slop-speech.mp3?alt=media&token=6b9ae562-83f2-4640-9909-b6060afbfb87" type="audio/mpeg">
  Your browser does not support the audio element.
</audio>

<br>


Finally, there is the **Music** creation section. As someone who knows a little bit of theory and song structure, I can tell you that in most songs, it uses some kind of common musical pattern. First I will go over one of the **Melodic** patterns, there is a famous **3-chord progression** (although there's also other ones [here](https://en.wikipedia.org/wiki/Chord_progression)), that's prominently used in 12-bar blues. A chord is the sound of more than one musical note, in most cases it's 3 or 4 notes. But the chords are structured in thirds, for example, the chord of C major would have C as the base note, E as the third note of the scale, and G as the fifth note. 

In the chord progression, Let's say the key is in C major, the first chord would be C, and generally it would be played within the first 4 bars, in its basic simple structure. The second chord would be based on the 4th note of the C major scale, in which case is the F chord (in which its base note is F out of the three notes played), which would start in the 4th and 5th bars, then go back to the first chord for the next two. Finally, there's the third chord, based on the 5th note of the C major scale, the G chord. That goes for one bar, then it goes to F, then back to C.

There's also other types of music patterns other than just melodic ones. Rhythmic patterns can be formed through repeating drum beats, syncopation (which is placing emphasis on notes between the main beats), or recurring note durations. Songs themselves, at least the ones with lyrics, often follow common structures such as _verse-chorus-verse-chorus-bridge-chorus_, while lyrics may use repeated rhyme schemes, refrains, and choruses. 

With the music-based AI models around today, my understanding would be that the AI models get trained with all the common music patterns being used in just about every genre, including popular music. I'm going to put this to the test with 2 prompts, one from the point of view of someone who knows a bit about how music theory works, and the other point of view, someone who knows nothing about the theory side of music, but want to create a basic song with the same lyrical motif, about someone who loves cheesecake. Keep this in mind, the **Lyria 3 Pro** model settings currently only has one tast of "Text-to-music".


**Prompt #1**, From POV of someone who knows a fair bit about Music Theory:

_"Generate a 12-bar blues song in the key of C major, with the main motif of the song being about a person's enjoyment of cheesecake."_


<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1781997288670-music-gen-fail.png?alt=media&token=ac82505f-8451-48d8-a312-597200dde7b2)

<br>

Here's the issue. It **failed to generate any music** with that specific prompt. It cannot generate music even if my prompt was "Create a generic 12-bar blues song". It cannot handle any prompt that has any technical music terms and patterns, and this is supposedly the "advanced" model to make music. So this is not really targeted at the people who want to have a certain genre and a certain structure, even a certain key. This AI music tool not actually aimed for people who know how common music structures work. It's aimed for people who want to have a generic hit song, with some bullshit lyrics that make no sense. If you're going to execute "lyrics making no sense" tactic, at least be creative about it. That's my blunt honest opinion.



**Prompt #2**, From POV who knows nothing about music:

"_Create a hit song about a person's love for cheesecake._"

<br>
<audio controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2Fcheesecake-swirl.wav?alt=media&token=f8d380d9-4188-4346-aa74-aeca696ffa50" type="audio/wav">
  Your browser does not support the audio element.
</audio>

<br>

Here's the song it put out. This is an absolutely terrible song it's created by the way, so this is the definitive soundtrack to AI slop, if you will. The lyrics aren't exactly inspiring either, but then again, I did do an unserious prompt. This is proof that a lot of the music-based AI models only really train it off of generic licensed music to avoid copyright issues, and it's been speculated as such on a few Reddit threads with this model specifically. I am glad though that copyright laws exist though for AI, because it can easily steal signature sounds off artists, and there'd be a million lawsuits coming their way if they trained it off of more famous songs.

**Prompt #3,** same POV as Prompt #2 but in a different genre:

_"Create a metal song about cheesecake."_

<br>
<audio controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2Fmetal-cheesecake.wav?alt=media&token=7977c648-b90f-4a38-8ea3-762cf2d2f17f" type="audio/wav">
  Your browser does not support the audio element.
</audio>

<br>

What is interesting though, is that it can do more than one genre, even though it can't understand the basic structure of music. This one is at least a bit more listenable, but it still lacks the quality and the soul of music being made by humans.



### 9.4 - A Very Brief Look at Colab Enterprise

Lastly in the AI phase, there is a feature called **Colab Enterprise**. Colab Enterprise is Google's version of Jupyter Notebook (another common tool for writing and running AI/data code at the same time, often in Python), letting people write and run AI and data analysis code on powerful cloud computers instead of their own machine. It's essentially designed for teams and businesses to collaborate and work with AI tools stored under Google Cloud.

There are some notebook templates for you to try out, but I will create my own little notebook. I'm going to test out this notebook by using the code from this [Beginner's guide here](https://medium.com/@aleksej.gudkov/artificial-intelligence-python-code-example-a-beginners-guide-04f3b8291c43). This is code that predicts house prices using machine learning tools. 

The notebook looks something like this, and the code is located inside the other-code folder inside my repo. There is also options to tune a model, but the example code it gives you when you begin to initialise it doesn't seem to work with the model it selected. That's all I'm going to cover for this particular section, because I'm not quite as nerdy or as interested in this specific part of AI anymore, but if you have access to this with the Google Cloud free trial or paid account, you can have a go yourself.


<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1782021821130-colab-enterprise-notebook-1.png?alt=media&token=2a959a27-5264-4998-a419-ccc7a2deaec0)

<br>

---
## Phase 10 - BigQuery

What is **BigQuery**? BigQuery is essentially a cloud-based database platform that handles and stores data using SQL (Stuctured Query Language). You load data into it and run SQL queries to quickly find patterns, generate reports, or answer questions from large amounts of information.

### 10.1 – Create a Dataset


<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1782192438278-bigquery-test-query-1.png?alt=media&token=6138d1dc-18bf-4a3a-8907-462d9a2b02f9)

<br>

I have created an experimental dataset with some mock data, with one table for now. Here's how I did it.

1. Open the **BigQuery Studio** page in Google Cloud.
2. In the **Explorer** pane on the left, click the **⋮ (three dots)** next to your project name.
3. Select **Create dataset**.
4. Fill in:

   * **Dataset ID** → something like `experimental_dataset`
   * **Location type** → Multi-region or Region
   * **Data location** → e.g. `australia-southeast1` if you want to keep it near your other resources
   * Leave the other settings at their defaults for now. Make sure you're using the Create table from **"Empty table"**.
5. Click **Create dataset**.

For experimentation, I basically just created one test table with a schema, and decided to insert data using SQL, then query the basic data (more in depth in 10.3):

```sql
INSERT INTO `your_project_id.experimental_dataset.test_users`
(user_id, username, email, age, country, created_at)
VALUES
(1, 'bob', 'bob@test.com', 25, 'NZ', CURRENT_TIMESTAMP()),
(2, 'alex', 'alex@test.com', 30, 'AU', CURRENT_TIMESTAMP()),
(3, 'sam', 'sam@test.com', 22, 'NZ', CURRENT_TIMESTAMP());

```



### 10.2 – Import CSV/JSON Data into Tables

In the same dataset, we are going to create two more tables. However, this time we are going to import data from both a CSV file and a JSON file. 

It's essentially the same way I created a table earlier, except the source is changing from "Empty table" to "Upload". The File format will be "CSV", and the table will be called "system_events". I also enabled the Auto-detect function in the schema, so it will read in the data from the CSV and create the schema and datatypes as appropriate. Again, everything else is set as default.

I did the exact same thing with the JSON file, except the file format is "JSONL (Newline delimited JSON)" and it's a new table name of "event_tracking".

Now I have two more tables created in this dataset, ready to query.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1782192369475-bigquery-tables.png?alt=media&token=b698a87e-d667-40a1-ae27-6f0421486574)

<br>

### 10.3 – Query Data with SQL 

Now we are going to test out some more queries, rather than just the "Select" and "Insert Into" queries, I will try some more queries within the SQL language.

The full SQL script is under the [BigQuery folder](https://github.com/crystalsawers/pitwall-telemetry-platform/tree/main/BigQuery) in the repo, with the filename of ["10.3 BigQueries.sql"](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/BigQuery/10.3%20BigQueries.sql). The following video is only showing the results that came from this script:

<br>
<video controls>
  <source src="https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2Fbigquery-queries.mp4?alt=media&token=f58e05fb-78e4-43c4-ad82-d4efa0927a75" type="video/mp4">
  Your browser does not support the video tag.
</video>
<br>


### 10.4 – SQL Scripting

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1782193780060-bigquery-sql-scripts.png?alt=media&token=93abcc4f-c3c3-43ce-9958-64c76417e138)

<br>

In the queries section, not only can you create and insert data into existing vis the BigQuery console, but you can also create a new dataset with tables using SQL itself as a script that does it all. If you're familiar with the SQL language though, just be aware that you **do** need to explicitly state your project id, your dataset, and the tables you use before you use **any** SQL statement (SELECT, INSERT, CREATE, etc.)

Once again, there is a common F1 theme to this, but this time it's 3 SQL scripts. The first one to create the schema (i.e. Create the database, then the tables), the second to insert data into the schema, the third to query and show data. The end result comes down to this example image above. Once again, you can find the SQL files inside the [BigQuery directory](https://github.com/crystalsawers/pitwall-telemetry-platform/tree/main/BigQuery), but if you want to test it out with BigQuery, be aware that you need to use your own Project ID for Google Cloud.



### 10.5 – Table Partitioning and Clustering

I'm going to create a new table (called `sensor_readings`) that involves some "Table Partitioning and Clustering" upon creation of the table. Still the same dataset, but new table and new data.

- **Source type:** Empty table
- **Project:** Project ID
- **Dataset:** `experimental_dataset`
- **Table:** `sensor_readings`

This is the following Schema with the following fields:

- sensor_id (integer)
- sensor_type (string, for non-programmers a string is a sequence of characters)
- location (string)
- value (decimal number)
- status (string)
- reading_time (timestamp)

In the same table creation screen, set Partitioning Settings to:

- **Partition by:** Field
- **Field:** reading_time
- **Type:** By day


Set clustering fields in this order, then create the table:

`sensor_type, location`

Once the table is created, you can click on the details and you should see this:

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1782196984186-bigquery-partition.png?alt=media&token=99168d64-dc0e-4247-bd77-afb0983030e4)

<br>

Then here's a simple query to test this out:

```sql
INSERT INTO `project-id.experimental_dataset.sensor_readings`
(sensor_id, sensor_type, location, value, status, reading_time)
VALUES
(1, 'temperature', 'lab-a', 21.5, 'ok', TIMESTAMP('2026-06-23 10:00:00')),
(2, 'humidity', 'lab-a', 55.2, 'ok', TIMESTAMP('2026-06-23 10:01:00')),
(3, 'temperature', 'lab-b', 22.1, 'ok', TIMESTAMP('2026-06-23 10:02:00')),
(4, 'pressure', 'lab-b', 101.3, 'warn', TIMESTAMP('2026-06-23 10:03:00'));

SELECT *
FROM `project-id.experimental_dataset.sensor_readings`
WHERE DATE(reading_time) = '2026-06-23'
ORDER BY sensor_id;
```

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1782197083403-bigquery-sensor.png?alt=media&token=2c892afb-95e4-4447-bb8b-e6b5f1435622)

<br>

**Note:** If you're getting some weird error regarding the sensor_id, I managed to fix it using this SQL query that deletes and re-creates the table with the proper partitioning and clustering.

```sql
DROP TABLE IF EXISTS `project-1f40dd62-739c-473a-b20.experimental_dataset.sensor_readings`;

CREATE TABLE `project-1f40dd62-739c-473a-b20.experimental_dataset.sensor_readings`
(
  sensor_id INT64,
  sensor_type STRING,
  location STRING,
  value FLOAT64,
  status STRING,
  reading_time TIMESTAMP
)
PARTITION BY DATE(reading_time)
CLUSTER BY sensor_type, location;

```


---
## Phase 11 - Cloud Storage

### 11.1 - Creating a storage bucket

When creating a storage bucket, you have to choose a "globally unique" name for it, so it can't just be named a "test-bucket", because everyone goes for that when first starting this task, so we have to be a bit more inventive than that. So I named it "testxample-bucket-6", fairly uninventive but somehow was not taken as a name. Choosing where to store data didn't have too many options for the region I was in (australia-southeast1), so I had to choose the "Region" option as the Location type, as the other options were more curated for the US, Asia, and Europe. Choosing how to store you data is very much dependent on what you want to use the bucket for whether it's a long-term or short-term project, and how much you want to save in costs. In my use case this is very much a short-term experiment, I chose the default "Standard" option, but it has other options for data that's infrequently accessed too, including one for disaster recovery. There's also options for Data protection and encryption, but I've left everything in the default settings. I've also saved the equivalent code for creating a storage bucket too, however it comes up with a message saying that it doesn't currently support encryption enforcement. 

```bash
gcloud storage buckets create gs://testxample-bucket-6 \
    --default-storage-class=STANDARD \
    --location=AUSTRALIA-SOUTHEAST1 \
    --uniform-bucket-level-access \
    --public-access-prevention

```

It's as simple as this, now you can go to the console and access it in Buckets > name of your bucket, and simply upload and transfer your data to another bucket.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1782440602990-created-storage-bucket.png?alt=media&token=d9112c1d-5249-4bb6-b592-c51fdb9a32ab)

<br>

### 11.2 - Adding objects to the storage bucket

I'm going to add some things now to the storage bucket, starting with uploading a few files first. It's pretty simple, just click the "Upload" menu and select "Upload files". I'm going to upload all my AI slop from Phase 9 in here first. When you click on an object though it gives you the details of the object, things like the file type, size, the Public/Authenicated URL, and even a preview depending on how big the file is. I'm later going to use this bucket for the Pub/Sub phase to add more things, but with a twist. 


<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1782441276244-storage-bucket-objects-1.png?alt=media&token=69b489fe-3743-478e-8a08-df72412c94ba)

<br>

---
## Phase 12 - Pub/Sub

**Google Cloud Pub/Sub** is a messaging service that allows applications and services to send messages (**publish**) to a topic, while other services receive those messages through **subscriptions**. It helps decouple systems so they can communicate asynchronously without needing direct connections.

### 12.1 Create Topic & Subscription

A topic is the destination that published messages are sent to.

**Steps:**

1. Search for Pub/Sub in the Google Cloud search and click to the Pub/Sub Console.
2. Select **Topics** → **Create Topic**.
3. Give it a name, such as `destination-bucket`. Note that the topic ID needs these requirements: "Must be 3-255 characters, start with a letter, and contain only the following characters: letters, numbers, dashes (-), periods (.), underscores (_), tildes (~), percents (%) or plus signs (+). Cannot start with goog."
4. Leave the default settings unless you want to experiment with additional features. 
5. Click **Create**.


When you create a topic it **automatically creates a default subscription** for you with the "-sub" at the end of your topic name. A subscription receives messages from a topic, and has a default delivery type as "Pull", but you can change that if you want to, with an option to write to Cloud Storage or BigQuery. But I've left everything as default for now. 



Here’s the rewritten version using the modern (and actually working) approach with `gcloud`:

---

### 12.2 Connect Storage Bucket (Pub/Sub Notification via gcloud)

We have to use the gcloud CLI inside the Cloud Shell to configure Cloud Storage to publish events into Pub/Sub by creating and using a notification system for this bucket, for messages to appear in the subscription console.

**Steps:**

1. Link the Cloud Storage bucket to Pub/Sub:

```bash
gcloud storage buckets notifications create \
  gs://testxample-bucket-6 \
  --topic=destination-bucket \
  --event-types=OBJECT_FINALIZE
```
Your output should look something like this:

```
WARNING: Topic already exists: projects/project-1f40dd62-739c-473a-b20/topics/destination-bucket
etag: '1'
event_types:
- OBJECT_FINALIZE
id: '1'
kind: storage#notification
payload_format: JSON_API_V1
selfLink: https://www.googleapis.com/storage/v1/b/testxample-bucket-6/notificationConfigs/1
topic: //pubsub.googleapis.com/projects/project-1f40dd62-739c-473a-b20/topics/destination-bucket
```
**Note:** This command assumes the topic doesn't already exist, so that's why I get the warning at the top.


---

2. Verify the notification configuration:

```bash
gcloud storage buckets notifications list \
  gs://testxample-bucket-6
```
Your output should look something like this:

```
---
Bucket URL: gs://testxample-bucket-6/
Notification Configuration:
  etag: '1'
  event_types:
  - OBJECT_FINALIZE
  id: '1'
  kind: storage#notification
  payload_format: JSON_API_V1
  selfLink: https://www.googleapis.com/storage/v1/b/testxample-bucket-6/notificationConfigs/1
  topic: //pubsub.googleapis.com/projects/project-1f40dd62-739c-473a-b20/topics/destination-bucket

```

---

3. Test the setup:

* Upload a file or folder into `testxample-bucket-6`
* Check the Pub/Sub subscription for received messages
* Alternatively, use this command to view the received messages: `gcloud pubsub subscriptions pull destination-bucket-sub --auto-ack`

In the CLI you should get something similar to this:

```
DATA: {
  "kind": "storage#object",
  "id": "testxample-bucket-6/local-scripts/instance_cs.sh/1782442981889115",
  "selfLink": "https://www.googleapis.com/storage/v1/b/testxample-bucket-6/o/local-scripts%2Finstance_cs.sh",
  "name": "local-scripts/instance_cs.sh",
  "bucket": "testxample-bucket-6",
  "generation": "1782442981889115",
  "metageneration": "1",
  "contentType": "text/x-sh",
  "timeCreated": "2026-06-26T03:03:01.895Z",
  "updated": "2026-06-26T03:03:01.895Z",
  "storageClass": "STANDARD",
  "timeStorageClassUpdated": "2026-06-26T03:03:01.895Z",
  "size": "2107",
  "md5Hash": "fAjG7ymybSWdjRYV5y9SHw==",
  "mediaLink": "https://storage.googleapis.com/download/storage/v1/b/testxample-bucket-6/o/local-scripts%2Finstance_cs.sh?generation=1782442981889115&alt=media",
  "crc32c": "TfEWQA==",
  "etag": "CNuoksb1o5UDEAE="
}

MESSAGE_ID: 19737222449068453
ORDERING_KEY: 
ATTRIBUTES: bucketId=testxample-bucket-6
eventTime=2026-06-26T03:03:01.895151Z
eventType=OBJECT_FINALIZE
notificationConfig=projects/_/buckets/testxample-bucket-6/notificationConfigs/1
objectGeneration=1782442981889115
objectId=local-scripts/instance_cs.sh
payloadFormat=JSON_API_V1
DELIVERY_ATTEMPT: 
ACK_STATUS: SUCCESS

```